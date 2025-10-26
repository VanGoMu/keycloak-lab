#!/bin/bash

# Keycloak Development Environment - Functional Test Suite
# Tests all components including Keycloak realms, users, and FastAPI integration

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Navigate to root
cd "$(dirname "$0")/../.."

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Keycloak Dev - Functional Test Suite                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

FAILED=0
PASSED=0
WARNINGS=0

print_test() {
    echo -e "${YELLOW}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
    ((PASSED++))
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    ((FAILED++))
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    ((WARNINGS++))
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected="$3"
    
    echo -n "  Testing: $test_name... "
    
    if eval "$test_command" | grep -q "$expected"; then
        echo -e "${GREEN}✅${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}❌${NC}"
        ((FAILED++))
        return 1
    fi
}

# ============================================
# 1. INFRASTRUCTURE CHECKS
# ============================================

print_test "[1/12] Infrastructure Checks"

echo -n "  Docker daemon... "
if docker info &> /dev/null; then
    echo -e "${GREEN}✅${NC}"
    ((PASSED++))
else
    echo -e "${RED}❌${NC}"
    echo -e "${RED}Docker is not running!${NC}"
    exit 1
fi

echo -n "  Docker Compose... "
if docker compose version &> /dev/null; then
    echo -e "${GREEN}✅${NC}"
    ((PASSED++))
else
    echo -e "${RED}❌${NC}"
    exit 1
fi

# ============================================
# 2. CONTAINER STATUS
# ============================================

print_test ""
print_test "[2/12] Container Status"

CONTAINERS=("keycloak-postgres" "keycloak-dev" "keycloak-mailhog" "keycloak-adminer" "keycloak-fastapi-demo")
for container in "${CONTAINERS[@]}"; do
    echo -n "  $container... "
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        STATUS=$(docker inspect --format='{{.State.Status}}' $container)
        if [ "$STATUS" = "running" ]; then
            echo -e "${GREEN}✅ running${NC}"
            ((PASSED++))
        else
            echo -e "${YELLOW}⚠️  $STATUS${NC}"
            ((WARNINGS++))
        fi
    else
        echo -e "${RED}❌ not found${NC}"
        ((FAILED++))
    fi
done

# ============================================
# 3. NETWORK CONNECTIVITY
# ============================================

print_test ""
print_test "[3/12] Network Connectivity"

PORTS=(
    "8080:Keycloak HTTP"
    "9000:Keycloak Metrics"
    "5432:PostgreSQL"
    "8025:Mailhog UI"
    "8081:Adminer"
    "8000:FastAPI"
)

# Helper: check if a TCP port on localhost is accepting connections.
# Tries (in order): ss (fast), nc (netcat) if available, a quick HTTP probe with curl,
# and finally the /dev/tcp bash socket as a last-resort fallback.
check_port() {
    local p=$1
    # Try ss with a sport filter (works on modern Linux)
    if command -v ss >/dev/null 2>&1 && ss -ltn "( sport = :$p )" >/dev/null 2>&1; then
        return 0
    fi

    # Try netcat if installed
    if command -v nc >/dev/null 2>&1; then
        if nc -z -w1 127.0.0.1 $p >/dev/null 2>&1; then
            return 0
        fi
    fi

    # Quick HTTP probe for web-like ports (fast timeout)
    if command -v curl >/dev/null 2>&1; then
        if curl -s --max-time 1 "http://127.0.0.1:$p/" >/dev/null 2>&1; then
            return 0
        fi
    fi

    # /dev/tcp fallback (bash built-in)
    if bash -c "cat < /dev/tcp/127.0.0.1/$p" >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

for port_info in "${PORTS[@]}"; do
    IFS=: read -r port name <<< "$port_info"
    echo -n "  Port $port ($name)... "

    if check_port "$port"; then
        echo -e "${GREEN}✅ listening${NC}"
        ((PASSED++))
    else
        echo -e "${RED}❌ not listening${NC}"
        ((FAILED++))
    fi
done

# ============================================
# 4. KEYCLOAK HEALTH
# ============================================

print_test ""
print_test "[4/12] Keycloak Health Checks"

echo -n "  Health endpoint... "
HEALTH=$(curl -s http://localhost:9000/health 2>/dev/null || echo "error")
if echo "$HEALTH" | grep -q "UP"; then
    echo -e "${GREEN}✅ UP${NC}"
    ((PASSED++))
else
    echo -e "${RED}❌ DOWN${NC}"
    echo "    Response: $HEALTH"
    ((FAILED++))
fi

echo -n "  Ready endpoint... "
if curl -s http://localhost:9000/health/ready 2>/dev/null | grep -q "UP"; then
    echo -e "${GREEN}✅ ready${NC}"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠️  not ready${NC}"
    ((WARNINGS++))
fi

echo -n "  Metrics endpoint... "
if curl -s http://localhost:9000/metrics 2>/dev/null | grep -q "jvm_memory"; then
    echo -e "${GREEN}✅ available${NC}"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠️  not available${NC}"
    ((WARNINGS++))
fi

# ============================================
# 5. KEYCLOAK ADMIN ACCESS
# ============================================

print_test ""
print_test "[5/12] Keycloak Admin Console"

echo -n "  Admin login page... "
ADMIN_PAGE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/admin/)
if [ "$ADMIN_PAGE" = "200" ] || [ "$ADMIN_PAGE" = "302" ]; then
    echo -e "${GREEN}✅ accessible${NC}"
    ((PASSED++))
else
    echo -e "${RED}❌ HTTP $ADMIN_PAGE${NC}"
    ((FAILED++))
fi

# ============================================
# 6. REALM CONFIGURATION
# ============================================

print_test ""
print_test "[6/12] Realm Configuration"

echo -n "  Master realm... "
MASTER_REALM=$(curl -s http://localhost:8080/realms/master/.well-known/openid-configuration 2>/dev/null)
if echo "$MASTER_REALM" | grep -q "issuer"; then
    echo -e "${GREEN}✅ configured${NC}"
    ((PASSED++))
else
    echo -e "${RED}❌ not found${NC}"
    ((FAILED++))
fi

echo -n "  demo-app realm... "
DEMO_REALM=$(curl -s http://localhost:8080/realms/demo-app/.well-known/openid-configuration 2>/dev/null)
if echo "$DEMO_REALM" | grep -q "issuer"; then
    echo -e "${GREEN}✅ configured${NC}"
    ((PASSED++))
    REALM_EXISTS=true
else
    echo -e "${RED}❌ NOT FOUND${NC}"
    echo ""
    echo -e "${YELLOW}    ⚠️  The 'demo-app' realm is missing!${NC}"
    echo ""
    echo -e "${YELLOW}    To fix this:${NC}"
    echo -e "    1. Access Keycloak Admin: ${BLUE}http://localhost:8080/admin${NC}"
    echo -e "    2. Login with: ${BLUE}admin / admin${NC}"
    echo -e "    3. Import realm: ${BLUE}docker/realms/demo-realm.json${NC}"
    echo ""
    echo -e "    ${YELLOW}Or run:${NC}"
    echo -e "    ${GREEN}docker cp docker/realms/demo-realm.json keycloak-dev:/tmp/${NC}"
    echo -e "    ${GREEN}docker exec keycloak-dev /opt/keycloak/bin/kc.sh import \\${NC}"
    echo -e "    ${GREEN}  --file /tmp/demo-realm.json${NC}"
    echo ""
    ((FAILED++))
    REALM_EXISTS=false
fi

# ============================================
# 7. KEYCLOAK OIDC ENDPOINTS
# ============================================

if [ "$REALM_EXISTS" = true ]; then
    print_test ""
    print_test "[7/12] OpenID Connect Endpoints"

    OIDC_CONFIG=$(curl -s http://localhost:8080/realms/demo-app/.well-known/openid-configuration 2>/dev/null)
    
    echo -n "  Authorization endpoint... "
    if echo "$OIDC_CONFIG" | grep -q "authorization_endpoint"; then
        echo -e "${GREEN}✅ found${NC}"
        ((PASSED++))
    else
        echo -e "${RED}❌${NC}"
        ((FAILED++))
    fi

    echo -n "  Token endpoint... "
    if echo "$OIDC_CONFIG" | grep -q "token_endpoint"; then
        echo -e "${GREEN}✅ found${NC}"
        ((PASSED++))
    else
        echo -e "${RED}❌${NC}"
        ((FAILED++))
    fi

    echo -n "  Userinfo endpoint... "
    if echo "$OIDC_CONFIG" | grep -q "userinfo_endpoint"; then
        echo -e "${GREEN}✅ found${NC}"
        ((PASSED++))
    else
        echo -e "${RED}❌${NC}"
        ((FAILED++))
    fi

    echo -n "  JWKS endpoint... "
    JWKS=$(curl -s http://localhost:8080/realms/demo-app/protocol/openid-connect/certs 2>/dev/null)
    if echo "$JWKS" | grep -q "keys"; then
        echo -e "${GREEN}✅ available${NC}"
        ((PASSED++))
    else
        echo -e "${RED}❌${NC}"
        ((FAILED++))
    fi
else
    print_test ""
    print_test "[7/12] OpenID Connect Endpoints - ${YELLOW}SKIPPED (realm missing)${NC}"
fi

# ============================================
# 8. USER AUTHENTICATION
# ============================================

if [ "$REALM_EXISTS" = true ]; then
    print_test ""
    print_test "[8/12] User Authentication"

    # Test demo-user login
    echo -n "  demo-user login... "
    USER_TOKEN=$(curl -s -X POST "http://localhost:8080/realms/demo-app/protocol/openid-connect/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "client_id=demo-app-frontend" \
      -d "grant_type=password" \
      -d "username=demo-user" \
      -d "password=Demo@User123" \
      2>/dev/null | jq -r '.access_token' 2>/dev/null || echo "null")
    
    if [ "$USER_TOKEN" != "null" ] && [ -n "$USER_TOKEN" ] && [ "$USER_TOKEN" != "" ]; then
        echo -e "${GREEN}✅ token obtained${NC}"
        ((PASSED++))
        USER_TOKEN_VALID=true
    else
        echo -e "${RED}❌ authentication failed${NC}"
        echo "    Check that user 'demo-user' exists with password 'Demo@User123'"
        ((FAILED++))
        USER_TOKEN_VALID=false
    fi

    # Test admin-user login
    echo -n "  admin-user login... "
    ADMIN_TOKEN=$(curl -s -X POST "http://localhost:8080/realms/demo-app/protocol/openid-connect/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "client_id=demo-app-frontend" \
      -d "grant_type=password" \
      -d "username=admin-user" \
      -d "password=Admin@User123" \
      2>/dev/null | jq -r '.access_token' 2>/dev/null || echo "null")
    
    if [ "$ADMIN_TOKEN" != "null" ] && [ -n "$ADMIN_TOKEN" ] && [ "$ADMIN_TOKEN" != "" ]; then
        echo -e "${GREEN}✅ token obtained${NC}"
        ((PASSED++))
        ADMIN_TOKEN_VALID=true
    else
        echo -e "${RED}❌ authentication failed${NC}"
        echo "    Check that user 'admin-user' exists with password 'Admin@User123'"
        ((FAILED++))
        ADMIN_TOKEN_VALID=false
    fi

    # Validate token structure
    if [ "$USER_TOKEN_VALID" = true ]; then
        echo -n "  Token validation... "
        TOKEN_INFO=$(echo "$USER_TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null || echo "{}")
        if echo "$TOKEN_INFO" | jq -e '.sub' &>/dev/null; then
            echo -e "${GREEN}✅ valid JWT${NC}"
            ((PASSED++))
        else
            echo -e "${YELLOW}⚠️  invalid structure${NC}"
            ((WARNINGS++))
        fi
    fi
else
    print_test ""
    print_test "[8/12] User Authentication - ${YELLOW}SKIPPED (realm missing)${NC}"
fi

# ============================================
# 9. FASTAPI INTEGRATION
# ============================================

print_test ""
print_test "[9/12] FastAPI Integration"

echo -n "  Health check... "
FASTAPI_HEALTH=$(curl -s http://localhost:8000/health 2>/dev/null || echo "error")
if echo "$FASTAPI_HEALTH" | grep -q "healthy"; then
    echo -e "${GREEN}✅ healthy${NC}"
    ((PASSED++))
else
    echo -e "${RED}❌ unhealthy${NC}"
    echo "    Response: $FASTAPI_HEALTH"
    ((FAILED++))
fi

echo -n "  Root endpoint... "
if curl -s http://localhost:8000/ 2>/dev/null | grep -q "FastAPI"; then
    echo -e "${GREEN}✅ responding${NC}"
    ((PASSED++))
else
    echo -e "${RED}❌ not responding${NC}"
    ((FAILED++))
fi

echo -n "  API docs... "
DOCS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/docs)
if [ "$DOCS_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ accessible${NC}"
    ((PASSED++))
else
    echo -e "${RED}❌ HTTP $DOCS_STATUS${NC}"
    ((FAILED++))
fi

# ============================================
# 10. FASTAPI AUTHENTICATION
# ============================================

if [ "$USER_TOKEN_VALID" = true ]; then
    print_test ""
    print_test "[10/12] FastAPI Authentication Flow"

    echo -n "  Login endpoint... "
    FASTAPI_TOKEN=$(curl -s -X POST http://localhost:8000/login \
      -H "Content-Type: application/json" \
      -d '{"username": "demo-user", "password": "Demo@User123"}' \
      2>/dev/null | jq -r '.access_token' 2>/dev/null || echo "null")
    
    if [ "$FASTAPI_TOKEN" != "null" ] && [ -n "$FASTAPI_TOKEN" ]; then
        echo -e "${GREEN}✅ working${NC}"
        ((PASSED++))
        FASTAPI_AUTH=true
    else
        echo -e "${RED}❌ failed${NC}"
        ((FAILED++))
        FASTAPI_AUTH=false
    fi

    if [ "$FASTAPI_AUTH" = true ]; then
        echo -n "  Profile endpoint... "
        PROFILE=$(curl -s http://localhost:8000/profile \
          -H "Authorization: Bearer $FASTAPI_TOKEN" 2>/dev/null)
        
        if echo "$PROFILE" | jq -e '.user.username' &>/dev/null; then
            USERNAME=$(echo "$PROFILE" | jq -r '.user.username')
            if [ "$USERNAME" = "demo-user" ]; then
                echo -e "${GREEN}✅ authenticated as $USERNAME${NC}"
                ((PASSED++))
            else
                echo -e "${YELLOW}⚠️  wrong user: $USERNAME${NC}"
                ((WARNINGS++))
            fi
        else
            echo -e "${RED}❌ invalid response${NC}"
            ((FAILED++))
        fi
    fi
else
    print_test ""
    print_test "[10/12] FastAPI Authentication - ${YELLOW}SKIPPED (no valid token)${NC}"
fi

# ============================================
# 11. ROLE-BASED ACCESS CONTROL
# ============================================

if [ "$ADMIN_TOKEN_VALID" = true ]; then
    print_test ""
    print_test "[11/12] Role-Based Access Control"

    # Get admin token from FastAPI
    ADMIN_FASTAPI_TOKEN=$(curl -s -X POST http://localhost:8000/login \
      -H "Content-Type: application/json" \
      -d '{"username": "admin-user", "password": "Admin@User123"}' \
      2>/dev/null | jq -r '.access_token' 2>/dev/null || echo "null")

    echo -n "  User role check... "
    USER_PROTECTED=$(curl -s http://localhost:8000/user-or-admin \
      -H "Authorization: Bearer $FASTAPI_TOKEN" 2>/dev/null)
    
    if echo "$USER_PROTECTED" | grep -q "user"; then
        echo -e "${GREEN}✅ user role validated${NC}"
        ((PASSED++))
    else
        echo -e "${RED}❌ role validation failed${NC}"
        ((FAILED++))
    fi

    if [ "$ADMIN_FASTAPI_TOKEN" != "null" ] && [ -n "$ADMIN_FASTAPI_TOKEN" ]; then
        echo -n "  Admin role check... "
        ADMIN_ENDPOINT=$(curl -s http://localhost:8000/admin \
          -H "Authorization: Bearer $ADMIN_FASTAPI_TOKEN" 2>/dev/null)
        
        if echo "$ADMIN_ENDPOINT" | grep -q "admin"; then
            echo -e "${GREEN}✅ admin role validated${NC}"
            ((PASSED++))
        else
            echo -e "${RED}❌ admin access failed${NC}"
            ((FAILED++))
        fi

        echo -n "  User denied admin... "
        USER_ADMIN_ATTEMPT=$(curl -s http://localhost:8000/admin \
          -H "Authorization: Bearer $FASTAPI_TOKEN" 2>/dev/null)
        
        if echo "$USER_ADMIN_ATTEMPT" | grep -q "requiere.*admin"; then
            echo -e "${GREEN}✅ correctly denied${NC}"
            ((PASSED++))
        else
            echo -e "${RED}❌ should be denied${NC}"
            ((FAILED++))
        fi
    fi
else
    print_test ""
    print_test "[11/12] RBAC Tests - ${YELLOW}SKIPPED (admin token invalid)${NC}"
fi

# ============================================
# 12. SUPPORTING SERVICES
# ============================================

print_test ""
print_test "[12/12] Supporting Services"

echo -n "  PostgreSQL... "
if docker exec keycloak-postgres pg_isready -U keycloak &>/dev/null; then
    echo -e "${GREEN}✅ ready${NC}"
    ((PASSED++))
else
    echo -e "${RED}❌ not ready${NC}"
    ((FAILED++))
fi

echo -n "  Mailhog UI... "
MAILHOG_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8025)
if [ "$MAILHOG_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ accessible${NC}"
    ((PASSED++))
else
    echo -e "${RED}❌ HTTP $MAILHOG_STATUS${NC}"
    ((FAILED++))
fi

echo -n "  Adminer... "
ADMINER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081)
if [ "$ADMINER_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ accessible${NC}"
    ((PASSED++))
else
    echo -e "${RED}❌ HTTP $ADMINER_STATUS${NC}"
    ((FAILED++))
fi

# ============================================
# SUMMARY
# ============================================

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                     Test Summary${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}Passed:${NC}   $PASSED"
echo -e "  ${RED}Failed:${NC}   $FAILED"
echo -e "  ${YELLOW}Warnings:${NC} $WARNINGS"
echo ""

# Final verdict
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           ✅ ALL TESTS PASSED SUCCESSFULLY                ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}📍 Quick Access URLs:${NC}"
    echo ""
    echo -e "  ${GREEN}Keycloak Admin:${NC}  http://localhost:8080/admin"
    echo -e "  ${GREEN}FastAPI App:${NC}     http://localhost:8000"
    echo -e "  ${GREEN}API Docs:${NC}        http://localhost:8000/docs"
    echo -e "  ${GREEN}Mailhog:${NC}         http://localhost:8025"
    echo -e "  ${GREEN}Adminer:${NC}         http://localhost:8081"
    echo ""
    echo -e "${BLUE}👤 Test Users:${NC}"
    echo ""
    echo -e "  ${GREEN}demo-user${NC}  / Demo@User123  (role: user)"
    echo -e "  ${GREEN}admin-user${NC} / Admin@User123 (role: admin)"
    echo ""
    echo -e "${BLUE}🧪 Quick Test:${NC}"
    echo ""
    echo -e "  ${GREEN}curl -s -X POST http://localhost:8000/login \\${NC}"
    echo -e "    ${GREEN}-H 'Content-Type: application/json' \\${NC}"
    echo -e "    ${GREEN}-d '{\"username\": \"demo-user\", \"password\": \"Demo@User123\"}' \\${NC}"
    echo -e "    ${GREEN}| jq '.access_token'${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║              ❌ SOME TESTS FAILED                         ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}🔍 Troubleshooting Steps:${NC}"
    echo ""
    
    if [ "$REALM_EXISTS" = false ]; then
        echo -e "${RED}1. Import the demo-app realm:${NC}"
        echo ""
        echo -e "   ${GREEN}# Copy realm file to container${NC}"
        echo -e "   ${BLUE}docker cp docker/realms/demo-realm.json keycloak-dev:/tmp/${NC}"
        echo ""
        echo -e "   ${GREEN}# Import the realm${NC}"
        echo -e "   ${BLUE}docker exec keycloak-dev /opt/keycloak/bin/kc.sh import \\${NC}"
        echo -e "   ${BLUE}  --file /tmp/demo-realm.json \\${NC}"
        echo -e "   ${BLUE}  --override true${NC}"
        echo ""
        echo -e "   ${GREEN}# Or restart with import flag${NC}"
        echo -e "   ${BLUE}cd docker${NC}"
        echo -e "   ${BLUE}docker compose -f docker-compose.dev.yml down${NC}"
        echo -e "   ${BLUE}docker compose -f docker-compose.dev.yml up -d${NC}"
        echo ""
    fi
    
    echo -e "${YELLOW}2. Check service logs:${NC}"
    echo ""
    echo -e "   ${BLUE}cd docker${NC}"
    echo -e "   ${BLUE}docker compose -f docker-compose.dev.yml logs keycloak-dev${NC}"
    echo -e "   ${BLUE}docker compose -f docker-compose.dev.yml logs keycloak-fastapi-demo${NC}"
    echo ""
    
    echo -e "${YELLOW}3. Verify containers are running:${NC}"
    echo ""
    echo -e "   ${BLUE}cd docker${NC}"
    echo -e "   ${BLUE}docker compose -f docker-compose.dev.yml ps${NC}"
    echo ""
    
    echo -e "${YELLOW}4. Restart services:${NC}"
    echo ""
    echo -e "   ${BLUE}cd docker${NC}"
    echo -e "   ${BLUE}docker compose -f docker-compose.dev.yml restart${NC}"
    echo ""
    
    exit 1
fi