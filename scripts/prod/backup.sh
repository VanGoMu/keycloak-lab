#!/bin/bash

# Script de backup para Keycloak
# Realiza backup de la base de datos PostgreSQL y la configuración

# set -e

# Directorio base del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuración
BACKUP_DIR="${PROJECT_ROOT}/backups"
DATE=$(date +%Y%m%d_%H%M%S)
DB_BACKUP_FILE="${BACKUP_DIR}/keycloak_db_${DATE}.sql"
REALM_BACKUP_DIR="${BACKUP_DIR}/realms_${DATE}"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Detectar entorno (prod o dev)
if docker ps | grep -q "keycloak-prod"; then
    KEYCLOAK_CONTAINER="keycloak-prod"
    POSTGRES_CONTAINER="keycloak-postgres"
elif docker ps | grep -q "keycloak-dev"; then
    KEYCLOAK_CONTAINER="keycloak-dev"
    POSTGRES_CONTAINER="keycloak-postgres"
else
    echo -e "${RED}❌ No se encuentra ningún contenedor de Keycloak en ejecución${NC}"
    exit 1
fi

echo -e "${YELLOW}📍 Usando contenedor: $KEYCLOAK_CONTAINER${NC}"

echo -e "${YELLOW}🔄 Iniciando backup de Keycloak...${NC}"

# Crear directorio de backups si no existe
mkdir -p "$BACKUP_DIR"
mkdir -p "$REALM_BACKUP_DIR"

# 1. Backup de PostgreSQL
echo -e "${YELLOW}📦 Haciendo backup de la base de datos PostgreSQL...${NC}"
docker exec $POSTGRES_CONTAINER pg_dump -U keycloak keycloak > "$DB_BACKUP_FILE"

if [ -f "$DB_BACKUP_FILE" ]; then
    echo -e "${GREEN}✅ Backup de base de datos guardado en: $DB_BACKUP_FILE${NC}"
    # Comprimir el backup
    gzip "$DB_BACKUP_FILE"
    echo -e "${GREEN}✅ Backup comprimido: ${DB_BACKUP_FILE}.gz${NC}"
else
    echo -e "${RED}❌ Error al crear backup de base de datos${NC}"
    exit 1
fi

# 2. Exportar realms desde Keycloak
echo -e "${YELLOW}📦 Exportando configuración de realms...${NC}"

# Load environment variables from docker/.env
if [ -f "${PROJECT_ROOT}/docker/.env" ]; then
    source "${PROJECT_ROOT}/docker/.env"
fi

# Set credentials from environment or use defaults
KC_ADMIN_USERNAME="${KC_ADMIN_USERNAME:-admin}"
KC_ADMIN_PASSWORD="${KC_ADMIN_PASSWORD:-admin}"

# Obtener token de admin
ADMIN_TOKEN=$(curl -k -s -X POST "https://localhost:8443/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=admin-cli" \
  -d "username=${KC_ADMIN_USERNAME}" \
  -d "password=${KC_ADMIN_PASSWORD}" \
  -d "grant_type=password" | jq -r '.access_token' 2>/dev/null || echo "")

if [ -n "$ADMIN_TOKEN" ] && [ "$ADMIN_TOKEN" != "null" ]; then
    # Obtener lista de realms
    REALMS=$(curl -k -s "https://localhost:8443/admin/realms" \
        -H "Authorization: Bearer $ADMIN_TOKEN" | jq -r '.[].realm' 2>/dev/null | grep -v "^master$" || echo "")
    
    if [ -n "$REALMS" ]; then
        for realm in $REALMS; do
            echo -e "${YELLOW}  Exportando realm: $realm${NC}"
            REALM_DATA=$(curl -k -s "https://localhost:8443/admin/realms/$realm" \
                -H "Authorization: Bearer $ADMIN_TOKEN")
            echo "$REALM_DATA" > "${REALM_BACKUP_DIR}/${realm}-realm.json"
        done
        echo -e "${GREEN}✅ Realms exportados en: $REALM_BACKUP_DIR${NC}"
    else
        echo -e "${YELLOW}⚠️  No se encontraron realms adicionales para exportar${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  No se pudo obtener token de admin, saltando export de realms${NC}"
fi

# 3. Backup de volúmenes (opcional)
echo -e "${YELLOW}📦 Información de volúmenes Docker:${NC}"
docker volume ls | grep keycloak

# 4. Crear archivo de información
cat > "${BACKUP_DIR}/info_${DATE}.txt" << EOF
Backup de Keycloak
==================
Fecha: $(date)
Host: $(hostname)
Usuario: $(whoami)

Contenedores activos:
$(docker ps --filter "name=keycloak" --format "table {{.Names}}\t{{.Status}}")

Versión de Keycloak:
$(docker exec $KEYCLOAK_CONTAINER /opt/keycloak/bin/kc.sh --version 2>/dev/null || echo "N/A")

Archivos incluidos:
- Base de datos: keycloak_db_${DATE}.sql.gz
- Realms: realms_${DATE}/
EOF

echo -e "${GREEN}✅ Información del backup guardada${NC}"

# 5. Limpiar backups antiguos (mantener últimos 7 días)
echo -e "${YELLOW}🧹 Limpiando backups antiguos (> 7 días)...${NC}"
find "$BACKUP_DIR" -type f -name "*.sql.gz" -mtime +7 -delete 2>/dev/null || true
find "$BACKUP_DIR" -type d -name "realms_*" -mtime +7 -exec rm -rf {} + 2>/dev/null || true

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           ✅ Backup completado exitosamente!              ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📍 Ubicación del backup: $BACKUP_DIR${NC}"
echo ""
echo -e "Archivos creados:"
ls -lh "$BACKUP_DIR" | tail -n 5
echo ""
echo -e "${YELLOW}💡 Para restaurar el backup, usa: ./restore.sh $DATE${NC}"
echo ""
