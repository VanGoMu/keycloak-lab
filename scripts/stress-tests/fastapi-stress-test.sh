#!/bin/bash

# FastAPI Stress Test
# Tests protected and public endpoints
# Uses Docker containers - no local installation required

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
FASTAPI_URL="${FASTAPI_URL:-http://host.docker.internal:8000}"
KEYCLOAK_URL="${KEYCLOAK_URL:-https://localhost:8443}"
REALM="${REALM:-demo-app}"
CLIENT_ID="${CLIENT_ID:-demo-app-frontend}"
KEYCLOAK_USERNAME="${KEYCLOAK_USERNAME:-demo-user}"
KEYCLOAK_PASSWORD="${KEYCLOAK_PASSWORD:-DemoUser123}"
CONCURRENT_USERS="${CONCURRENT_USERS:-10}"
REQUESTS_PER_USER="${REQUESTS_PER_USER:-100}"

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  FastAPI Stress Test${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  FastAPI URL: $FASTAPI_URL"
echo "  Concurrent Users: $CONCURRENT_USERS"
echo "  Requests per User: $REQUESTS_PER_USER"
echo "  Total Requests: $((CONCURRENT_USERS * REQUESTS_PER_USER))"
echo ""

# Check Docker availability
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    echo "Please install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

echo -e "${YELLOW}Pulling Docker images...${NC}"
docker pull httpd:alpine > /dev/null 2>&1
docker pull curlimages/curl:latest > /dev/null 2>&1
echo -e "${GREEN}✅ Images ready${NC}"
echo ""

# Create results directory
RESULTS_DIR="stress-test-results/fastapi-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS_DIR"

# Docker run helper function for Apache Bench
run_ab_docker() {
    local url="$1"
    local output_file="$2"
    local auth_header="$3"
    
    if [ -n "$auth_header" ]; then
        docker run --rm --network host \
            --add-host host.docker.internal:host-gateway \
            httpd:alpine ab -n $((CONCURRENT_USERS * REQUESTS_PER_USER)) \
            -c $CONCURRENT_USERS \
            -H "$auth_header" \
            -k "$url" > "$output_file" 2>&1
    else
        docker run --rm --network host \
            --add-host host.docker.internal:host-gateway \
            httpd:alpine ab -n $((CONCURRENT_USERS * REQUESTS_PER_USER)) \
            -c $CONCURRENT_USERS \
            -k "$url" > "$output_file" 2>&1
    fi
}

# Get access token using curl Docker image
echo -e "${YELLOW}Obtaining access token...${NC}"

# Debug: show what we're sending
if [ -n "$DEBUG" ]; then
    echo "DEBUG: URL=$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token"
    echo "DEBUG: KEYCLOAK_USERNAME=$KEYCLOAK_USERNAME"
    echo "DEBUG: KEYCLOAK_PASSWORD=$KEYCLOAK_PASSWORD"
    echo "DEBUG: CLIENT_ID=$CLIENT_ID"
fi

TOKEN_RESPONSE=$(docker run --rm --network host \
    --add-host host.docker.internal:host-gateway \
    curlimages/curl:latest \
    -k -s -X POST "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=$KEYCLOAK_USERNAME" \
    -d "password=$KEYCLOAK_PASSWORD" \
    -d "grant_type=password" \
    -d "client_id=$CLIENT_ID")S

# Extract token using grep and sed (more robust parsing)
TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*' | sed 's/"access_token":"//')
[ -z "$TOKEN" ] && TOKEN=""

if [ -z "$TOKEN" ]; then
    echo -e "${RED}Failed to obtain access token${NC}"
    # Debug: show error details if available
    ERROR_MSG=$(echo "$TOKEN_RESPONSE" | grep -o '"error_description":"[^"]*' | sed 's/"error_description":"//' 2>/dev/null)
    if [ -n "$ERROR_MSG" ]; then
        echo -e "${RED}Error: $ERROR_MSG${NC}"
    elif [ ${#TOKEN_RESPONSE} -gt 100 ]; then
        echo -e "${YELLOW}Response received but token extraction may have failed${NC}"
        echo -e "${YELLOW}Response length: ${#TOKEN_RESPONSE} bytes${NC}"
        echo -e "${YELLOW}First 150 chars: ${TOKEN_RESPONSE:0:150}${NC}"
    elif [ -n "$TOKEN_RESPONSE" ]; then
        echo -e "${YELLOW}Short response received: $TOKEN_RESPONSE${NC}"
    else
        echo -e "${RED}No response from Keycloak server${NC}"
    fi
    echo -e "${YELLOW}Continuing with public endpoint tests only...${NC}"
    TOKEN=""
else
    echo -e "${GREEN}✅ Access token obtained (${#TOKEN} bytes)${NC}"
fi
echo ""

echo -e "${GREEN}Starting stress tests...${NC}"
echo ""

# Test 1: Public Health Endpoint
echo -e "${YELLOW}Test 1: Health Endpoint (Public)${NC}"
run_ab_docker "$FASTAPI_URL/health" "$RESULTS_DIR/health-endpoint.txt"

echo -e "${GREEN}✅ Health endpoint test completed${NC}"
grep -E "Requests per second|Time per request|Failed requests" "$RESULTS_DIR/health-endpoint.txt" 2>/dev/null || echo "  Check detailed results in $RESULTS_DIR/health-endpoint.txt"
echo ""

# Test 2: Root Endpoint
echo -e "${YELLOW}Test 2: Root Endpoint (Public)${NC}"
run_ab_docker "$FASTAPI_URL/" "$RESULTS_DIR/root-endpoint.txt"

echo -e "${GREEN}✅ Root endpoint test completed${NC}"
grep -E "Requests per second|Time per request|Failed requests" "$RESULTS_DIR/root-endpoint.txt" 2>/dev/null || echo "  Check detailed results in $RESULTS_DIR/root-endpoint.txt"
echo ""

# Test 3: Protected Endpoint (if token available)
if [ -n "$TOKEN" ]; then
    echo -e "${YELLOW}Test 3: Protected Endpoint (Requires Auth)${NC}"
    run_ab_docker "$FASTAPI_URL/protected" "$RESULTS_DIR/protected-endpoint.txt" "Authorization: Bearer $TOKEN"
    
    echo -e "${GREEN}✅ Protected endpoint test completed${NC}"
    grep -E "Requests per second|Time per request|Failed requests" "$RESULTS_DIR/protected-endpoint.txt" 2>/dev/null || echo "  Check detailed results in $RESULTS_DIR/protected-endpoint.txt"
    echo ""
    
    # Test 4: User Info Endpoint
    echo -e "${YELLOW}Test 4: User Info Endpoint (Requires Auth)${NC}"
    run_ab_docker "$FASTAPI_URL/userinfo" "$RESULTS_DIR/userinfo-endpoint.txt" "Authorization: Bearer $TOKEN"
    
    echo -e "${GREEN}✅ User info endpoint test completed${NC}"
    grep -E "Requests per second|Time per request|Failed requests" "$RESULTS_DIR/userinfo-endpoint.txt" 2>/dev/null || echo "  Check detailed results in $RESULTS_DIR/userinfo-endpoint.txt"
    echo ""
fi

# Generate summary report
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Test Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

cat > "$RESULTS_DIR/summary.txt" << EOF
FastAPI Stress Test Summary
============================
Date: $(date)
Configuration:
  - FastAPI URL: $FASTAPI_URL
  - Concurrent Users: $CONCURRENT_USERS
  - Requests per User: $REQUESTS_PER_USER
  - Total Requests: $((CONCURRENT_USERS * REQUESTS_PER_USER))
  - Load Tool: Docker (Apache Bench)

Results:
--------
EOF

for file in "$RESULTS_DIR"/*.txt; do
    if [ "$file" != "$RESULTS_DIR/summary.txt" ]; then
        echo "" >> "$RESULTS_DIR/summary.txt"
        echo "$(basename $file .txt):" >> "$RESULTS_DIR/summary.txt"
        grep -E "Requests per second|Failed requests|Time per request" "$file" >> "$RESULTS_DIR/summary.txt" 2>/dev/null || true
    fi
done

cat "$RESULTS_DIR/summary.txt"
echo ""
echo -e "${GREEN}✅ All tests completed!${NC}"
echo -e "${YELLOW}Results saved to: $RESULTS_DIR${NC}"
echo ""
echo -e "${BLUE}View detailed results:${NC}"
echo "  cat $RESULTS_DIR/summary.txt"
echo "  ls -la $RESULTS_DIR/"
echo ""
