#!/bin/bash

# Script de inicio rápido para Keycloak
# Este script configura e inicia el entorno de Keycloak

set -e

echo "🚀 Iniciando Keycloak Setup..."

# Cargar variables de entorno

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verificar que Docker está instalado
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker no está instalado. Por favor instala Docker primero.${NC}"
    exit 1
fi

if ! command -v docker compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose no está instalado. Por favor instala Docker Compose primero.${NC}"
    exit 1
fi

# Crear archivo .env si no existe
if [ ! -f .env ]; then
    echo -e "${YELLOW}📝 Creando archivo .env desde .env.example...${NC}"
    cp .env.example .env
    echo -e "${GREEN}✅ Archivo .env creado. Por favor revisa y ajusta los valores.${NC}"
fi

# Crear directorios necesarios
echo -e "${YELLOW}📁 Creando directorios necesarios...${NC}"
mkdir -p realms
mkdir -p providers
mkdir -p themes
mkdir -p nginx/certs
mkdir -p keycloak-custom

# Verificar que el archivo demo-realm.json existe
if [ ! -f realms/demo-realm.json ]; then
    echo -e "${YELLOW}⚠️  No se encuentra demo-realm.json en el directorio realms/${NC}"
fi

# Preguntar modo de inicio
echo ""
echo -e "${YELLOW}Selecciona el modo de inicio:${NC}"
echo "1) Desarrollo (start-dev) - HTTP, auto-reload"
echo "2) Producción (start --optimized) - HTTPS, optimizado"
read -p "Selecciona (1 o 2): " mode

# Iniciar servicios
echo ""
echo -e "${GREEN}🐳 Iniciando contenedores...${NC}"

if [ "$mode" == "1" ]; then
    docker compose up -d postgres mailhog adminer keycloak-dev
    KEYCLOAK_URL="http://localhost:8080"
else
    echo -e "${YELLOW}ℹ️  Modo producción requiere configuración adicional (certificados SSL)${NC}"
    echo -e "${YELLOW}   Editando docker-compose.yml para descomentar keycloak-prod...${NC}"
    docker compose up -d postgres keycloak-prod
    KEYCLOAK_URL="https://localhost:8443"
fi

echo ""
echo -e "${GREEN}✅ Contenedores iniciados!${NC}"
echo ""

# Esperar a que Keycloak esté listo
echo -e "${YELLOW}⏳ Esperando a que Keycloak esté listo...${NC}"
sleep 5

# Mostrar estado
docker compose ps

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              🎉 Keycloak está listo!                      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📍 URLs de acceso:${NC}"
echo ""
echo -e "   ${GREEN}Keycloak Admin Console:${NC}"
echo -e "   → $KEYCLOAK_URL/admin"
echo -e "   Usuario: admin"
echo -e "   Contraseña: admin"
echo ""
echo -e "   ${GREEN}Health Check:${NC}"
echo -e "   → http://localhost:9000/health"
echo ""
echo -e "   ${GREEN}Metrics (Prometheus):${NC}"
echo -e "   → http://localhost:9000/metrics"
echo ""
echo -e "   ${GREEN}Mailhog (Email Testing):${NC}"
echo -e "   → http://localhost:8025"
echo ""
echo -e "   ${GREEN}Adminer (PostgreSQL UI):${NC}"
echo -e "   → http://localhost:8081"
echo -e "   Sistema: PostgreSQL"
echo -e "   Servidor: postgres"
echo -e "   Usuario: keycloak"
echo -e "   Password: keycloak_password_change_me"
echo ""
echo -e "${YELLOW}📚 Comandos útiles:${NC}"
echo ""
echo -e "   Ver logs:"
echo -e "   ${GREEN}docker compose logs -f keycloak-dev${NC}"
echo ""
echo -e "   Detener servicios:"
echo -e "   ${GREEN}docker compose down${NC}"
echo ""
echo -e "   Reiniciar Keycloak:"
echo -e "   ${GREEN}docker compose restart keycloak-dev${NC}"
echo ""
echo -e "   Acceder al contenedor:"
echo -e "   ${GREEN}docker exec -it keycloak-dev bash${NC}"
echo ""
echo -e "${YELLOW}📖 Lee el README.md para más información sobre personalización${NC}"
echo ""
