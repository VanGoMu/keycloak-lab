#!/bin/bash

# Script to generate SSL certificates for Keycloak production

set -e

CERTS_DIR="../../nginx/certs"
DAYS=365

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Navigate to script directory
cd "$(dirname "$0")"

echo -e "${YELLOW}🔐 Generating SSL certificates...${NC}"

# Create directory
mkdir -p "$CERTS_DIR"

# Generate self-signed certificate
openssl req -x509 -nodes -days $DAYS -newkey rsa:2048 \
  -keyout "$CERTS_DIR/server.key" \
  -out "$CERTS_DIR/server.crt" \
  -subj "/C=US/ST=State/L=City/O=MyOrg/OU=IT/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,DNS:keycloak-prod,DNS:keycloak-dev,IP:127.0.0.1"

echo ""
echo -e "${GREEN}✅ Certificates generated successfully!${NC}"
echo ""
echo -e "Location: $(cd "$CERTS_DIR" && pwd)"
echo -e "  • server.crt (Certificate)"
echo -e "  • server.key (Private Key)"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: Self-signed certificates${NC}"
echo ""
echo -e "Use for:"
echo -e "  ✅ Development and testing"
echo -e "  ✅ Local environment"
echo ""
echo -e "DO NOT use for:"
echo -e "  ❌ Production environments"
echo -e "  ❌ Public-facing services"
echo ""
echo -e "For production, obtain certificates from:"
echo -e "  • Let's Encrypt (free, automated)"
echo -e "  • Commercial CA (DigiCert, GlobalSign, etc.)"
echo -e "  • Enterprise CA"
echo -e "  • Cloud provider (AWS ACM, Azure, GCP)"
echo ""

# Show certificate info
echo -e "${YELLOW}Certificate Information:${NC}"
openssl x509 -in "$CERTS_DIR/server.crt" -text -noout | grep -E "Subject:|Issuer:|Not Before|Not After|DNS:"
echo ""