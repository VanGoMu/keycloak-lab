#!/bin/bash

# Script de restauración para Keycloak
# Restaura backups de base de datos y realms

# set -e

# Directorio base del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables para skip confirmation
SKIP_CONFIRMATION=false

# Procesar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes)
            SKIP_CONFIRMATION=true
            shift
            ;;
        *)
            TIMESTAMP=$1
            shift
            ;;
    esac
done

# Detectar entorno
if docker ps | grep -q "keycloak-prod"; then
    KEYCLOAK_CONTAINER="keycloak-prod"
    POSTGRES_CONTAINER="keycloak-postgres"
    COMPOSE_SERVICE="keycloak-prod"
elif docker ps | grep -q "keycloak-dev"; then
    KEYCLOAK_CONTAINER="keycloak-dev"
    POSTGRES_CONTAINER="keycloak-postgres"
    COMPOSE_SERVICE="keycloak-dev"
else
    echo -e "${RED}❌ No se encuentra ningún contenedor de Keycloak en ejecución${NC}"
    exit 1
fi

# Verificar argumentos
if [ -z "$TIMESTAMP" ]; then
    echo -e "${RED}❌ Uso: $0 [-y|--yes] <timestamp>${NC}"
    echo ""
    echo "Opciones:"
    echo "  -y, --yes    Omitir confirmación"
    echo ""
    echo "Backups disponibles:"
    ls -1 "${PROJECT_ROOT}/backups"/*.sql.gz 2>/dev/null | sed 's/.*keycloak_db_/  /' | sed 's/.sql.gz//' || echo "  No hay backups disponibles"
    exit 1
fi

BACKUP_DIR="${PROJECT_ROOT}/backups"
DB_BACKUP_FILE="${BACKUP_DIR}/keycloak_db_${TIMESTAMP}.sql.gz"
REALM_BACKUP_DIR="${BACKUP_DIR}/realms_${TIMESTAMP}"

echo -e "${YELLOW}🔄 Restaurando Keycloak desde backup: $TIMESTAMP${NC}"
echo ""

# Verificar que existan los archivos
if [ ! -f "$DB_BACKUP_FILE" ]; then
    echo -e "${RED}❌ No se encuentra el archivo de backup: $DB_BACKUP_FILE${NC}"
    exit 1
fi

# Confirmación
if [ "$SKIP_CONFIRMATION" = false ]; then
    echo -e "${RED}⚠️  ADVERTENCIA: Esta operación sobrescribirá los datos actuales de Keycloak${NC}"
    read -p "¿Estás seguro de continuar? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        echo -e "${YELLOW}Operación cancelada${NC}"
        exit 0
    fi
fi

# 1. Detener Keycloak
echo -e "${YELLOW}⏸️  Deteniendo Keycloak...${NC}"
docker stop $KEYCLOAK_CONTAINER > /dev/null 2>&1

# 2. Restaurar base de datos
echo -e "${YELLOW}📦 Restaurando base de datos PostgreSQL...${NC}"

# Descomprimir backup
gunzip -c "$DB_BACKUP_FILE" > /tmp/keycloak_restore.sql

# Terminar todas las conexiones activas
echo -e "${YELLOW}   Cerrando conexiones activas...${NC}"
docker exec $POSTGRES_CONTAINER psql -U keycloak -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'keycloak' AND pid <> pg_backend_pid();" > /dev/null 2>&1 || true

# Eliminar base de datos existente y recrearla
docker exec $POSTGRES_CONTAINER psql -U keycloak -d postgres -c "DROP DATABASE IF EXISTS keycloak;"
docker exec $POSTGRES_CONTAINER psql -U keycloak -d postgres -c "CREATE DATABASE keycloak;"

# Restaurar datos
docker exec -i $POSTGRES_CONTAINER psql -U keycloak -d keycloak < /tmp/keycloak_restore.sql

# Limpiar archivo temporal
rm /tmp/keycloak_restore.sql

echo -e "${GREEN}✅ Base de datos restaurada${NC}"

# 3. Restaurar realms (si existen)
if [ -d "$REALM_BACKUP_DIR" ]; then
    echo -e "${YELLOW}📦 Restaurando realms...${NC}"
    
    # Copiar archivos de realm al directorio de importación
    cp -r "$REALM_BACKUP_DIR"/*.json ./realms/ 2>/dev/null || true
    
    echo -e "${GREEN}✅ Realms copiados a ./realms/${NC}"
    echo -e "${YELLOW}   Los realms se importarán al iniciar Keycloak con --import-realm${NC}"
else
    echo -e "${YELLOW}⚠️  No se encontraron backups de realms${NC}"
fi

# 4. Reiniciar Keycloak
echo -e "${YELLOW}🚀 Reiniciando Keycloak...${NC}"
docker start $KEYCLOAK_CONTAINER

# Esperar a que Keycloak esté listo
echo -e "${YELLOW}⏳ Esperando a que Keycloak esté listo...${NC}"
MAX_ATTEMPTS=30
ATTEMPT=0
until curl -k -sf https://localhost:8443/realms/master > /dev/null 2>&1; do
    ATTEMPT=$((ATTEMPT + 1))
    if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
        echo -e "${RED}❌ Keycloak no está respondiendo${NC}"
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        ✅ Restauración completada exitosamente!           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Load environment variables from docker/.env
if [ -f "${PROJECT_ROOT}/docker/.env" ]; then
    source "${PROJECT_ROOT}/docker/.env"
fi

echo -e "${YELLOW}📍 Keycloak Admin Console: https://localhost:8443/admin${NC}"
echo -e "   Usuario: \${KC_ADMIN_USERNAME} (ver docker/.env)"
echo -e "   Password: \${KC_ADMIN_PASSWORD} (ver docker/.env)"
echo ""
echo -e "Verificar logs:"
echo -e "${GREEN}docker logs -f $KEYCLOAK_CONTAINER${NC}"
echo ""
