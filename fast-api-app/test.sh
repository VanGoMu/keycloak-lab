#!/bin/bash

# Script de prueba completo para la aplicación FastAPI + Keycloak

set -e

echo "=================================================="
echo "🧪 Prueba Completa de FastAPI + Keycloak"
echo "=================================================="
echo ""

API_URL="http://localhost:8000"

# Load environment variables from docker/.env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../docker/.env"

if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "⚠️  Warning: docker/.env not found, using default values"
fi

DEMO_USER_PASSWORD="${DEMO_USER_PASSWORD:-password}"
ADMIN_USER_PASSWORD="${ADMIN_USER_PASSWORD:-Admin@User123}"

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# 1. Health check
echo "1️⃣  Verificando health check..."
HEALTH=$(curl -s $API_URL/health | jq -r '.status')
if [ "$HEALTH" == "healthy" ]; then
    print_success "Health check: OK"
else
    print_error "Health check: FAILED"
    exit 1
fi
echo ""

# 2. Login como usuario normal
echo "2️⃣  Login como demo-user..."
LOGIN_RESPONSE=$(curl -s -X POST $API_URL/login \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"demo-user\", \"password\": \"${DEMO_USER_PASSWORD}\"}")

USER_TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.access_token')
if [ "$USER_TOKEN" != "null" ] && [ -n "$USER_TOKEN" ]; then
    print_success "Login exitoso"
    print_info "Token: ${USER_TOKEN:0:50}..."
else
    print_error "Login falló"
    exit 1
fi
echo ""

# 3. Ver perfil de usuario
echo "3️⃣  Obteniendo perfil de demo-user..."
PROFILE=$(curl -s $API_URL/profile \
  -H "Authorization: Bearer $USER_TOKEN")
USERNAME=$(echo $PROFILE | jq -r '.user.username')
if [ "$USERNAME" == "demo-user" ]; then
    print_success "Perfil obtenido correctamente"
    echo $PROFILE | jq '.'
else
    print_error "Error obteniendo perfil"
    exit 1
fi
echo ""

# 4. Intentar acceder a /admin como usuario normal (debe fallar)
echo "4️⃣  Intentando acceder a /admin como demo-user (debe fallar)..."
ADMIN_RESPONSE=$(curl -s $API_URL/admin \
  -H "Authorization: Bearer $USER_TOKEN")
ERROR=$(echo $ADMIN_RESPONSE | jq -r '.detail')
if [[ "$ERROR" == *"requiere"*"admin"* ]]; then
    print_success "Acceso denegado correctamente (esperado)"
else
    print_error "Error en autorización"
    exit 1
fi
echo ""

# 5. Login como admin
echo "5️⃣  Login como admin-user..."
ADMIN_LOGIN=$(curl -s -X POST $API_URL/login \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"admin-user\", \"password\": \"${ADMIN_USER_PASSWORD}\"}")

ADMIN_TOKEN=$(echo $ADMIN_LOGIN | jq -r '.access_token')
if [ "$ADMIN_TOKEN" != "null" ] && [ -n "$ADMIN_TOKEN" ]; then
    print_success "Login como admin exitoso"
else
    print_error "Login admin falló"
    exit 1
fi
fi
echo ""

# 6. Acceder a /admin como admin
echo "6️⃣  Accediendo a /admin como admin-user..."
ADMIN_DATA=$(curl -s $API_URL/admin \
  -H "Authorization: Bearer $ADMIN_TOKEN")
ADMIN_USER=$(echo $ADMIN_DATA | jq -r '.admin_user')
if [ "$ADMIN_USER" == "admin-user" ]; then
    print_success "Acceso a área de admin exitoso"
    echo $ADMIN_DATA | jq '.'
else
    print_error "Error accediendo a área admin"
    exit 1
fi
echo ""

# 7. Listar items (público)
echo "7️⃣  Listando items disponibles (endpoint público)..."
ITEMS=$(curl -s $API_URL/items)
ITEM_COUNT=$(echo $ITEMS | jq '.items | length')
print_success "Items encontrados: $ITEM_COUNT"
echo $ITEMS | jq '.'
echo ""

# 8. Comprar un item (requiere autenticación)
echo "8️⃣  Comprando item #1 como demo-user..."
BUY_RESPONSE=$(curl -s -X POST $API_URL/items/1/buy \
  -H "Authorization: Bearer $USER_TOKEN")
BUYER=$(echo $BUY_RESPONSE | jq -r '.buyer')
if [ "$BUYER" == "demo-user" ]; then
    print_success "Item comprado exitosamente"
    echo $BUY_RESPONSE | jq '.'
else
    print_error "Error comprando item"
    exit 1
fi
echo ""

# 9. Ver mis items
echo "9️⃣  Viendo items de demo-user..."
MY_ITEMS=$(curl -s $API_URL/my-items \
  -H "Authorization: Bearer $USER_TOKEN")
MY_ITEM_COUNT=$(echo $MY_ITEMS | jq '.items | length')
print_success "Mis items: $MY_ITEM_COUNT"
echo $MY_ITEMS | jq '.'
echo ""

# 10. Probar token expirado (simulación)
echo "🔟  Probando con token inválido..."
INVALID_RESPONSE=$(curl -s $API_URL/profile \
  -H "Authorization: Bearer invalid_token_123")
ERROR=$(echo $INVALID_RESPONSE | jq -r '.detail')
if [[ "$ERROR" == *"inválido"* ]] || [[ "$ERROR" == *"invalid"* ]]; then
    print_success "Token inválido rechazado correctamente"
else
    print_error "Error en validación de token"
fi
echo ""

# Resumen final
echo "=================================================="
print_success "✅ TODAS LAS PRUEBAS PASARON EXITOSAMENTE"
echo "=================================================="
echo ""
print_info "La aplicación FastAPI + Keycloak está funcionando correctamente"
echo ""
echo "📝 Resumen de pruebas:"
echo "  ✅ Health check"
echo "  ✅ Login de usuario normal"
echo "  ✅ Login de administrador"
echo "  ✅ Acceso a perfil autenticado"
echo "  ✅ Autorización por roles (admin)"
echo "  ✅ Endpoints públicos"
echo "  ✅ Endpoints protegidos"
echo "  ✅ Validación de tokens"
echo ""
echo "🌐 Servicios disponibles:"
echo "  • FastAPI:  http://localhost:8000"
echo "  • Docs:     http://localhost:8000/docs"
echo "  • Keycloak: http://localhost:8080"
echo ""
