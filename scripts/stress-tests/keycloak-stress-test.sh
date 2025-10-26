#!/bin/bash

# Keycloak Stress Test
# Tests authentication endpoints, token generation, and user operations
# Uses Docker containers - no local installation required

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
KEYCLOAK_URL="${KEYCLOAK_URL:-https://host.docker.internal:8443}"
REALM="${REALM:-demo-app}"
CLIENT_ID="${CLIENT_ID:-demo-app-frontend}"
USERNAME="${USERNAME:-demo-user}"
PASSWORD="${PASSWORD:-Demo@User123}"
CONCURRENT_USERS="${CONCURRENT_USERS:-10}"
REQUESTS_PER_USER="${REQUESTS_PER_USER:-100}"
DURATION="${DURATION:-60}"

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Keycloak Stress Test${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Keycloak URL: $KEYCLOAK_URL"
echo "  Realm: $REALM"
echo "  Client ID: $CLIENT_ID"
echo "  Concurrent Users: $CONCURRENT_USERS"
echo "  Requests per User: $REQUESTS_PER_USER"
echo "  Duration: ${DURATION}s"
echo ""

# Check Docker availability
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    echo "Please install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

# Create results directory
RESULTS_DIR="stress-test-results/keycloak-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS_DIR"

echo -e "${GREEN}Starting stress tests using Docker...${NC}"
echo ""

# Docker run helper function for Apache Bench
run_ab_docker() {
    local url="$1"
    local output_file="$2"
    local post_data="$3"
    local content_type="$4"
    
    if [ -n "$post_data" ]; then
        # POST request
        echo "$post_data" | docker run --rm -i --network host \
            --add-host host.docker.internal:host-gateway \
            httpd:alpine ab -n $((CONCURRENT_USERS * REQUESTS_PER_USER)) \
            -c $CONCURRENT_USERS \
            -p /dev/stdin \
            -T "$content_type" \
            "$url" > "$output_file" 2>&1
    else
        # GET request
        docker run --rm --network host \
            --add-host host.docker.internal:host-gateway \
            httpd:alpine ab -n $((CONCURRENT_USERS * REQUESTS_PER_USER)) \
            -c $CONCURRENT_USERS \
            -k "$url" > "$output_file" 2>&1
    fi
}

echo -e "${YELLOW}Pulling Apache Bench Docker image...${NC}"
docker pull httpd:alpine > /dev/null 2>&1
echo -e "${GREEN}✅ Image ready${NC}"
echo ""

# Test 1: Token Endpoint
echo -e "${YELLOW}Test 1: Token Generation Endpoint${NC}"
TOKEN_URL="$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token"
TOKEN_DATA="username=$USERNAME&password=$PASSWORD&grant_type=password&client_id=$CLIENT_ID"

run_ab_docker "$TOKEN_URL" "$RESULTS_DIR/token-endpoint.txt" "$TOKEN_DATA" "application/x-www-form-urlencoded"

echo -e "${GREEN}✅ Token endpoint test completed${NC}"
grep -E "Requests per second|Time per request|Failed requests" "$RESULTS_DIR/token-endpoint.txt" 2>/dev/null || echo "  Check detailed results in $RESULTS_DIR/token-endpoint.txt"
echo ""

# Test 2: JWKS Endpoint (public endpoint)
echo -e "${YELLOW}Test 2: JWKS Endpoint (Public Key Discovery)${NC}"
JWKS_URL="$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/certs"

run_ab_docker "$JWKS_URL" "$RESULTS_DIR/jwks-endpoint.txt"

echo -e "${GREEN}✅ JWKS endpoint test completed${NC}"
grep -E "Requests per second|Time per request|Failed requests" "$RESULTS_DIR/jwks-endpoint.txt" 2>/dev/null || echo "  Check detailed results in $RESULTS_DIR/jwks-endpoint.txt"
echo ""

# Test 3: OpenID Configuration
echo -e "${YELLOW}Test 3: OpenID Configuration Endpoint${NC}"
OIDC_URL="$KEYCLOAK_URL/realms/$REALM/.well-known/openid-configuration"

run_ab_docker "$OIDC_URL" "$RESULTS_DIR/openid-config.txt"

echo -e "${GREEN}✅ OpenID configuration test completed${NC}"
grep -E "Requests per second|Time per request|Failed requests" "$RESULTS_DIR/openid-config.txt" 2>/dev/null || echo "  Check detailed results in $RESULTS_DIR/openid-config.txt"
echo ""

# Test 4: Health Endpoint
echo -e "${YELLOW}Test 4: Health Endpoint${NC}"
HEALTH_URL="$KEYCLOAK_URL/health/ready"

run_ab_docker "$HEALTH_URL" "$RESULTS_DIR/health-endpoint.txt"

echo -e "${GREEN}✅ Health endpoint test completed${NC}"
grep -E "Requests per second|Time per request|Failed requests" "$RESULTS_DIR/health-endpoint.txt" 2>/dev/null || echo "  Check detailed results in $RESULTS_DIR/health-endpoint.txt"
echo ""

# Generate summary report
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Test Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

cat > "$RESULTS_DIR/summary.txt" << EOF
Keycloak Stress Test Summary
=============================
Date: $(date)
Configuration:
  - Keycloak URL: $KEYCLOAK_URL
  - Realm: $REALM
  - Concurrent Users: $CONCURRENT_USERS
  - Requests per User: $REQUESTS_PER_USER
  - Total Requests: $((CONCURRENT_USERS * REQUESTS_PER_USER))

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
echo "  cat $RESULTS_DIR/token-endpoint.txt"
echo ""
