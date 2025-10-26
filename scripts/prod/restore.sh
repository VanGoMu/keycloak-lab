#!/bin/bash

# Script de restauración para Keycloak
# Restaura backups de base de datos y realms

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Verificar argumentos
if [ -z "$1" ]; then
    echo -e "${RED}❌ Uso: $0 <timestamp>${NC}"
    echo ""
    echo "Backups disponibles:"
    ls -1 backups/*.sql.gz 2>/dev/null | sed 's/.*keycloak_db_/  /' | sed 's/.sql.gz//' || echo "  No hay backups disponibles"
    exit 1
fi

TIMESTAMP=$1
BACKUP_DIR="./backups"
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
echo -e "${RED}⚠️  ADVERTENCIA: Esta operación sobrescribirá los datos actuales de Keycloak${NC}"
read -p "¿Estás seguro de continuar? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo -e "${YELLOW}Operación cancelada${NC}"
    exit 0
fi

# 1. Detener Keycloak
echo -e "${YELLOW}⏸️  Deteniendo Keycloak...${NC}"
docker compose stop keycloak-dev 2>/dev/null || docker compose stop keycloak-prod 2>/dev/null || true

# 2. Restaurar base de datos
echo -e "${YELLOW}📦 Restaurando base de datos PostgreSQL...${NC}"

# Descomprimir backup
gunzip -c "$DB_BACKUP_FILE" > /tmp/keycloak_restore.sql

# Eliminar base de datos existente y recrearla
docker exec keycloak-postgres psql -U keycloak -d postgres -c "DROP DATABASE IF EXISTS keycloak;"
docker exec keycloak-postgres psql -U keycloak -d postgres -c "CREATE DATABASE keycloak;"

# Restaurar datos
docker exec -i keycloak-postgres psql -U keycloak -d keycloak < /tmp/keycloak_restore.sql

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
docker compose up -d keycloak-dev 2>/dev/null || docker compose up -d keycloak-prod 2>/dev/null

# Esperar a que Keycloak esté listo
echo -e "${YELLOW}⏳ Esperando a que Keycloak esté listo...${NC}"
sleep 10

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        ✅ Restauración completada exitosamente!           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📍 Keycloak Admin Console: http://localhost:8080/admin${NC}"
echo ""
echo -e "Verificar logs:"
echo -e "${GREEN}docker compose logs -f keycloak-dev${NC}"
echo ""
