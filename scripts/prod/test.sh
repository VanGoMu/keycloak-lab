#!/bin/bash

# Script to test Keycloak production configuration

#set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Navigate to root
cd "$(dirname "$0")/../.."

# Load environment variables from docker/.env
if [ -f "docker/.env" ]; then
    source docker/.env
fi
DEMO_USER_PASSWORD="${DEMO_USER_PASSWORD:-password}"

echo -e "${BLUE}🧪 Testing Keycloak Production Configuration${NC}"
echo "================================================"
echo ""

FAILED=0
PASSED=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected="$3"
    
    echo -n "Testing: $test_name... "
    
    if eval "$test_command" | grep -q "$expected"; then
        echo -e "${GREEN}✅ PASSED${NC}"
        ((PASSED++))
    else
        echo -e "${RED}❌ FAILED${NC}"
        ((FAILED++))
    fi
}

# 1. Health check
echo -e "${YELLOW}1️⃣  Health Check${NC}"
run_test "HTTPS Health Endpoint" \
    "curl -k -s https://localhost:9000/health/ready" \
    "UP"
echo ""

# 2. HTTP disabled
echo -e "${YELLOW}2️⃣  Security Configuration${NC}"
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>&1 | grep -qE "000|refused"; then
    echo -e "Testing: HTTP disabled... ${GREEN}✅ PASSED${NC}"
    ((PASSED++))
else
    echo -e "Testing: HTTP disabled... ${YELLOW}⚠️  WARNING${NC}"
fi
echo ""

# 3. Metrics
echo -e "${YELLOW}3️⃣  Metrics & Monitoring${NC}"
run_test "Prometheus Metrics" \
    "curl -k -s https://localhost:9000/metrics" \
    "jvm_memory"
echo ""

# 4. Token acquisition
echo -e "${YELLOW}4️⃣  Authentication Flow${NC}"
TOKEN=$(curl -k -s -X POST "https://localhost:8443/realms/demo-app/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${DEMO_USER_NAME}" \
  -d "password=${DEMO_USER_PASSWORD}" \
  -d "grant_type=password" \
  -d "client_id=demo-app-frontend" \
  | jq -r '.access_token' 2>/dev/null || echo "")

if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
    echo -e "Testing: Token acquisition... ${GREEN}✅ PASSED${NC}"
    ((PASSED++))
else
    echo -e "Testing: Token acquisition... ${RED}❌ FAILED${NC}"
    echo -e "Execute command manually to create dummy user:"
    echo -e "  > scripts/stress-tests/create-demo-user.sh"
    ((FAILED++))
fi
echo ""

# 5. JWKS endpoint
echo -e "${YELLOW}5️⃣  OpenID Configuration${NC}"
run_test "JWKS Endpoint" \
    "curl -k -s https://localhost:8443/realms/demo-app/protocol/openid-connect/certs" \
    "keys"
echo ""

# 6. Cache configuration
echo -e "${YELLOW}6️⃣  Performance${NC}"
echo -n "Testing: Infinispan cache... "
if docker exec keycloak-prod /opt/keycloak/bin/kc.sh show-config 2>&1 | grep -q "kc.cache.*ispn"; then
    echo -e "${GREEN}✅ PASSED${NC}"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠️  WARNING${NC}"
fi
echo ""

# 7. Optimized build
echo -e "${YELLOW}7️⃣  Build Optimization${NC}"
echo -n "Testing: Optimized startup... "
if docker logs keycloak-prod 2>&1 | grep -q "started in"; then
    echo -e "${GREEN}✅ PASSED${NC}"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠️  WARNING${NC}"
fi
echo ""

# 8. Container health
echo -e "${YELLOW}8️⃣  Container Status${NC}"
echo -n "Testing: Container health... "
HEALTH=$(docker inspect --format='{{.State.Health.Status}}' keycloak-prod 2>/dev/null || echo "unknown")
if [ "$HEALTH" = "healthy" ]; then
    echo -e "${GREEN}✅ PASSED${NC}"
    ((PASSED++))
else
    echo -e "${RED}❌ FAILED (Status: $HEALTH)${NC}"
    ((FAILED++))
fi
echo ""

# Summary
echo "================================================"
echo -e "${BLUE}Test Summary${NC}"
echo "================================================"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    echo ""
    echo "Access URLs:"
    echo "  • Admin Console: https://localhost:8443/admin"
    echo "  • Metrics: http://localhost:9000/metrics"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    echo ""
    echo "Check logs:"
    echo "  cd docker && docker compose -f docker-compose.prod.yml logs -f keycloak-prod"
    echo ""
    exit 1
fi