#!/bin/bash

# Keycloak Development Mode Startup Script
# Starts Keycloak in development mode with HTTP

set -e

echo "🚀 Starting Keycloak in Development Mode..."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Navigate to root directory
cd "$(dirname "$0")/../.."

# Check Docker installation
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

if ! command -v docker compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose is not installed.${NC}"
    exit 1
fi

# Create .env file if it doesn't exist
if [ ! -f docker/.env ]; then
    echo -e "${YELLOW}📝 Creating .env file from template...${NC}"
    cp docker/.env.example docker/.env
    echo -e "${GREEN}✅ .env file created. Review and adjust if needed.${NC}"
fi

# Create necessary directories
echo -e "${YELLOW}📁 Creating necessary directories...${NC}"
mkdir -p keycloak/realms
mkdir -p keycloak/providers
mkdir -p keycloak/themes
mkdir -p nginx/certs

# Check for demo realm
if [ ! -f keycloak/realms/demo-realm.json ]; then
    echo -e "${YELLOW}⚠️  demo-realm.json not found in keycloak/realms/${NC}"
fi

# Create Docker network
docker network create keycloak-network 2>/dev/null || true

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Starting Keycloak - Development Mode${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Features:${NC}"
echo -e "   • HTTP enabled on port 8080"
echo -e "   • Theme hot-reload"
echo -e "   • Cache disabled"
echo -e "   • ⚠️  NOT for production"
echo ""

echo -e "${GREEN}🐳 Starting containers...${NC}"

# Start services from docker directory
cd docker
docker compose -f docker-compose.dev.yml up -d
cd ..

echo ""
echo -e "${GREEN}✅ Containers started!${NC}"
echo ""

# Wait for Keycloak
echo -e "${YELLOW}⏳ Waiting for Keycloak to be ready...${NC}"
echo -e "${YELLOW}   This may take 30-60 seconds...${NC}"
sleep 10

cd docker
docker compose -f docker-compose.dev.yml ps
cd ..

# Health check
MAX_WAIT=120
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    if docker inspect --format='{{.State.Health.Status}}' keycloak-dev 2>/dev/null | grep -q "healthy"; then
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
    echo -e "${YELLOW}   Check logs: cd docker && docker compose -f docker-compose.dev.yml logs -f${NC}"
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              🎉 Keycloak is Ready!                        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📍 Access URLs:${NC}"
echo ""
echo -e "   ${GREEN}Keycloak Admin Console:${NC}"
echo -e "   → ${BLUE}http://localhost:8080/admin${NC}"
echo -e "   Username: admin"
echo -e "   Password: admin"
echo ""
echo -e "   ${GREEN}Health Check:${NC}"
echo -e "   → http://localhost:9000/health"
echo ""
echo -e "   ${GREEN}Metrics:${NC}"
echo -e "   → http://localhost:9000/metrics"
echo ""
echo -e "   ${GREEN}Mailhog (Email Testing):${NC}"
echo -e "   → http://localhost:8025"
echo ""
echo -e "   ${GREEN}Adminer (Database UI):${NC}"
echo -e "   → http://localhost:8081"
echo ""
echo -e "   ${GREEN}FastAPI Demo:${NC}"
echo -e "   → http://localhost:8000"
echo -e "   → http://localhost:8000/docs"
echo ""
echo -e "${YELLOW}📚 Useful Commands:${NC}"
echo ""
echo -e "   View logs:"
echo -e "   ${GREEN}cd docker && docker compose -f docker-compose.dev.yml logs -f${NC}"
echo ""
echo -e "   Stop services:"
echo -e "   ${GREEN}cd docker && docker compose -f docker-compose.dev.yml down${NC}"
echo ""
echo -e "   Restart Keycloak:"
echo -e "   ${GREEN}cd docker && docker compose -f docker-compose.dev.yml restart keycloak-dev${NC}"
echo ""
echo -e "${YELLOW}📖 Read the README.md for more information${NC}"
echo ""