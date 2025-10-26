#!/bin/bash

# Let's Encrypt SSL Certificate Manager
# Generates and renews valid SSL certificates using official Certbot Docker image
#
# Usage:
#   Generate:  ./generate-valid-certs.sh your-domain.com your-email@example.com
#   Renew:     ./generate-valid-certs.sh --renew

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Navigate to root
cd "$(dirname "$0")/../.."

# Check if renew mode
if [ "$1" = "--renew" ] || [ "$1" = "-r" ]; then
    # Renew mode
    echo ""
    echo -e "${BLUE}🔄 Renewing Let's Encrypt Certificates${NC}"
    echo ""
    
    # Find domain from existing certificate
    if [ -f "nginx/certs/server.crt" ]; then
        DOMAIN=$(openssl x509 -in nginx/certs/server.crt -noout -subject | sed -n 's/.*CN=\([^,]*\).*/\1/p')
        echo -e "${CYAN}Domain:${NC} $DOMAIN"
    else
        echo -e "${RED}❌ No certificate found to renew${NC}"
        echo -e "${YELLOW}Run with domain and email to generate new certificate${NC}"
        exit 1
    fi
    
    # Check Docker
    if ! docker info &> /dev/null; then
        echo -e "${RED}❌ Docker is not running${NC}"
        exit 1
    fi
    
    # Create temp directory
    TEMP_CERTS=$(mktemp -d)
    
    # Renew using Certbot Docker - output directly to temp
    docker run --rm \
      --name certbot-renew \
      -p 80:80 \
      -v "$TEMP_CERTS:/etc/letsencrypt" \
      certbot/certbot renew \
        --standalone \
        --non-interactive
    
    # Copy renewed certificates
    if [ -f "$TEMP_CERTS/live/$DOMAIN/fullchain.pem" ]; then
        cp "$TEMP_CERTS/live/$DOMAIN/fullchain.pem" nginx/certs/server.crt
        cp "$TEMP_CERTS/live/$DOMAIN/privkey.pem" nginx/certs/server.key
        chmod 644 nginx/certs/server.crt
        chmod 600 nginx/certs/server.key
        
        echo ""
        echo -e "${GREEN}✅ Certificates renewed and copied${NC}"
        
        # Restart Keycloak if running
        if docker ps | grep -q keycloak-prod; then
            echo -e "${CYAN}🔄 Restarting Keycloak...${NC}"
            cd docker
            docker compose -f docker-compose.prod.yml restart keycloak-prod
            echo -e "${GREEN}✅ Keycloak restarted${NC}"
        fi
    else
        echo -e "${RED}❌ Renewal failed${NC}"
        rm -rf "$TEMP_CERTS"
        exit 1
    fi
    
    # Cleanup
    rm -rf "$TEMP_CERTS"
    echo ""
    exit 0
fi

# Parse arguments for generation mode
DOMAIN="${1}"
EMAIL="${2}"

# Show usage if no arguments
if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║       Let's Encrypt Certificate Manager                  ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Usage:${NC}"
    echo ""
    echo -e "  ${YELLOW}Generate new certificate:${NC}"
    echo -e "  ${GREEN}$0 <domain> <email>${NC}"
    echo ""
    echo -e "  ${YELLOW}Renew existing certificate:${NC}"
    echo -e "  ${GREEN}$0 --renew${NC}"
    echo ""
    echo -e "${CYAN}Examples:${NC}"
    echo -e "  ${GREEN}$0 keycloak.example.com admin@example.com${NC}"
    echo -e "  ${GREEN}$0 --renew${NC}"
    echo ""
    echo -e "${YELLOW}Requirements:${NC}"
    echo -e "  • Domain must point to this server (DNS A record)"
    echo -e "  • Port 80 must be accessible from internet"
    echo -e "  • Docker must be running"
    echo ""
    exit 1
fi

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       Let's Encrypt Certificate Generator                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Configuration:${NC}"
echo -e "  Domain: ${GREEN}$DOMAIN${NC}"
echo -e "  Email:  ${GREEN}$EMAIL${NC}"
echo -e "  Image:  ${YELLOW}certbot/certbot${NC} (Docker Hub Official)"
echo ""

# Create directories
mkdir -p nginx/certs

# Check Docker
if ! docker info &> /dev/null; then
    echo -e "${RED}❌ Docker is not running${NC}"
    echo ""
    echo -e "${YELLOW}Start Docker and try again${NC}"
    exit 1
fi

# Create temp directory for Certbot
TEMP_CERTS=$(mktemp -d)

# Generate certificate
echo -e "${CYAN}🔐 Generating certificate...${NC}"
echo ""

docker run --rm \
  --name certbot \
  -p 80:80 \
  -v "$TEMP_CERTS:/etc/letsencrypt" \
  certbot/certbot certonly \
    --standalone \
    --non-interactive \
    --agree-tos \
    --email "$EMAIL" \
    -d "$DOMAIN" \
    --preferred-challenges http

if [ $? -ne 0 ]; then
    echo ""
    echo -e "${RED}❌ Certificate generation failed${NC}"
    echo ""
    echo -e "${YELLOW}Common issues:${NC}"
    echo -e "  • Port 80 not accessible from internet"
    echo -e "  • DNS not properly configured"
    echo -e "  • Another service using port 80"
    echo ""
    echo -e "${CYAN}Debug:${NC}"
    echo -e "  Check DNS: ${BLUE}dig +short $DOMAIN${NC}"
    echo -e "  Check port: ${BLUE}sudo lsof -i :80${NC}"
    echo ""
    rm -rf "$TEMP_CERTS"
    exit 1
fi

# Copy certificates
echo ""
echo -e "${CYAN}📋 Copying certificates...${NC}"

cp "$TEMP_CERTS/live/$DOMAIN/fullchain.pem" nginx/certs/server.crt
cp "$TEMP_CERTS/live/$DOMAIN/privkey.pem" nginx/certs/server.key
chmod 644 nginx/certs/server.crt
chmod 600 nginx/certs/server.key

# Cleanup temp directory
rm -rf "$TEMP_CERTS"

# Update .env
if [ -f docker/.env ]; then
    if grep -q "^KC_HOSTNAME=" docker/.env; then
        sed -i.bak "s/^KC_HOSTNAME=.*/KC_HOSTNAME=$DOMAIN/" docker/.env
    else
        echo "KC_HOSTNAME=$DOMAIN" >> docker/.env
    fi
fi

# Success
echo ""
echo -e "${GREEN}✅ Certificate generated successfully!${NC}"
echo ""
echo -e "${BLUE}Certificate Information:${NC}"
openssl x509 -in nginx/certs/server.crt -noout -subject -dates -ext subjectAltName
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           ✅ READY FOR PRODUCTION!                        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Files:${NC}"
echo -e "  Certificate: ${GREEN}nginx/certs/server.crt${NC}"
echo -e "  Private Key: ${GREEN}nginx/certs/server.key${NC}"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo ""
echo -e "  ${YELLOW}1.${NC} Start production:"
echo -e "     ${BLUE}./scripts/prod/start.sh${NC}"
echo ""
echo -e "  ${YELLOW}2.${NC} Access Keycloak:"
echo -e "     ${BLUE}https://$DOMAIN/admin${NC}"
echo ""
echo -e "  ${YELLOW}3.${NC} Setup auto-renewal (cron):"
echo -e "     ${BLUE}crontab -e${NC}"
echo -e "     ${GREEN}0 0,12 * * * cd $(pwd) && $0 --renew >> /var/log/certbot.log 2>&1${NC}"
echo ""
