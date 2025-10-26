#!/bin/bash

# Keycloak Production Mode Startup Script
# Starts Keycloak in optimized production mode with HTTPS

set -e

echo "🚀 Starting Keycloak in Production Mode..."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Navigate to root directory
cd "$(dirname "$0")/../.."

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed.${NC}"
    exit 1
fi

if ! command -v docker compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose is not installed.${NC}"
    exit 1
fi

# Check OpenSSL
if ! command -v openssl &> /dev/null; then
    echo -e "${RED}❌ OpenSSL is not installed.${NC}"
    exit 1
fi

# Create .env file
if [ ! -f docker/.env ]; then
    echo -e "${YELLOW}📝 Creating .env file from template...${NC}"
    cp docker/.env.example docker/.env
    echo -e "${GREEN}✅ .env file created.${NC}"
    echo -e "${YELLOW}⚠️  Change default passwords in production!${NC}"
fi

# Create directories
echo -e "${YELLOW}📁 Creating necessary directories...${NC}"
mkdir -p keycloak/realms
mkdir -p keycloak/providers
mkdir -p keycloak/themes
mkdir -p nginx/certs
mkdir -p keycloak/keycloak-custom

# Check/Generate SSL certificates
if [ ! -f nginx/certs/server.crt ] || [ ! -f nginx/certs/server.key ]; then
    echo ""
    echo -e "${YELLOW}🔐 SSL certificates not found${NC}"
    echo -e "${YELLOW}   Generating self-signed certificates...${NC}"
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout nginx/certs/server.key \
      -out nginx/certs/server.crt \
      -subj "/C=US/ST=State/L=City/O=MyOrg/OU=IT/CN=localhost" \
      -addext "subjectAltName=DNS:localhost,DNS:keycloak-prod,IP:127.0.0.1" \
      2>/dev/null
    
    echo -e "${GREEN}✅ Certificates generated${NC}"
    echo -e "${YELLOW}   ⚠️  Self-signed certificates (testing only)${NC}"
    echo ""
    echo -e "${YELLOW}   For production, use valid certificates from:${NC}"
    echo -e "      • Let's Encrypt (certbot)"
    echo -e "      • Enterprise CA"
    echo -e "      • Cloud provider"
    echo ""
else
    echo -e "${GREEN}✅ SSL certificates found${NC}"
fi

# Check demo realm
if [ ! -f keycloak/realms/demo-realm.json ]; then
    echo -e "${YELLOW}⚠️  demo-realm.json not found${NC}"
fi

# Create Docker network
docker network create keycloak-network 2>/dev/null || true

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Starting Keycloak - Production Mode${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Features:${NC}"
echo -e "   • HTTPS on port 8443"
echo -e "   • Optimized build"
echo -e "   • HTTP disabled"
echo -e "   • Connection pooling"
echo -e "   • ⚠️  Self-signed certificates"
echo ""

echo -e "${GREEN}🐳 Starting containers...${NC}"

# Build and start from docker directory
echo -e "${YELLOW}🔨 Building optimized Keycloak image...${NC}"
cd docker
docker compose -f docker-compose.prod.yml -f ../monitoring/docker-compose.yml up -d --build
cd ..

echo ""
echo -e "${GREEN}✅ Containers started!${NC}"
echo ""

# Wait for Keycloak
echo -e "${YELLOW}⏳ Waiting for Keycloak to be ready...${NC}"
echo -e "${YELLOW}   This may take 60-90 seconds...${NC}"
sleep 15

cd docker
docker compose -f docker-compose.prod.yml ps
cd ..

# Health check
MAX_WAIT=180
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    if docker inspect --format='{{.State.Health.Status}}' keycloak-prod 2>/dev/null | grep -q "healthy"; then
        echo ""
        echo -e "${GREEN}✅ Keycloak is ready and healthy!${NC}"
        break
    fi
    sleep 5
    WAITED=$((WAITED + 5))
    echo -n "."
done

if [ $WAITED -ge $MAX_WAIT ]; then
    echo ""
    echo -e "${YELLOW}⚠️  Health check took longer than expected${NC}"
    echo -e "${YELLOW}   Check logs: cd docker && docker compose -f docker-compose.prod.yml logs -f${NC}"
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║      ✅ Keycloak Production started successfully!        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📍 Access Points:${NC}"
echo -e "   Keycloak: ${GREEN}https://localhost:8443${NC}"
echo -e "   Admin Console: ${GREEN}https://localhost:8443/admin${NC}"
echo -e "   Username: \${KC_ADMIN_USERNAME} (ver docker/.env)"
echo -e "   Password: \${KC_ADMIN_PASSWORD} (ver docker/.env)"
echo ""
echo -e "   ${YELLOW}⚠️  Browser Security Warning:${NC}"
echo -e "   Your browser will show a warning for self-signed certificate."
echo -e "   Click 'Advanced' → 'Proceed to localhost'"
echo ""
echo -e "   ${GREEN}Health Check:${NC}"
echo -e "   → http://localhost:9000/health"
echo ""
echo -e "   ${GREEN}Metrics:${NC}"
echo -e "   → http://localhost:9000/metrics"
echo ""
echo -e "   ${GREEN}Mailhog:${NC}"
echo -e "   → http://localhost:8025"
echo ""
echo -e "   ${GREEN}Adminer:${NC}"
echo -e "   → http://localhost:8081"
echo ""
echo -e "   ${GREEN}FastAPI Demo:${NC}"
echo -e "   → http://localhost:8000"
echo ""
echo -e "${YELLOW}📚 Commands:${NC}"
echo ""
echo -e "   View logs:"
echo -e "   ${GREEN}cd docker && docker compose -f docker-compose.prod.yml logs -f${NC}"
echo ""
echo -e "   Stop services:"
echo -e "   ${GREEN}cd docker && docker compose -f docker-compose.prod.yml down${NC}"
echo ""
echo -e "  ${YELLOW}Test before production deployment:${NC}"
script_cmd="./scripts/prod/test.sh"
echo -e "   ${GREEN}${script_cmd}${NC}"
eval $script_cmd