#!/bin/bash

# Script de backup para Keycloak
# Realiza backup de la base de datos PostgreSQL y la configuración

set -e

# Configuración
BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d_%H%M%S)
DB_BACKUP_FILE="${BACKUP_DIR}/keycloak_db_${DATE}.sql"
REALM_BACKUP_DIR="${BACKUP_DIR}/realms_${DATE}"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🔄 Iniciando backup de Keycloak...${NC}"

# Crear directorio de backups si no existe
mkdir -p "$BACKUP_DIR"
mkdir -p "$REALM_BACKUP_DIR"

# 1. Backup de PostgreSQL
echo -e "${YELLOW}📦 Haciendo backup de la base de datos PostgreSQL...${NC}"
docker exec keycloak-postgres pg_dump -U keycloak keycloak > "$DB_BACKUP_FILE"

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
echo -e "${YELLOW}📦 Exportando realms de Keycloak...${NC}"

# Obtener lista de realms (excepto master)
REALMS=$(docker exec keycloak-dev /opt/keycloak/bin/kcadm.sh get realms \
    --server http://localhost:8080 \
    --realm master \
    --user keycloak_admin \
    --password keycloak@pass123StrNG \
    --format csv \
    --fields realm 2>/dev/null | tail -n +2 | grep -v "^master$" || echo "")

if [ -n "$REALMS" ]; then
    for realm in $REALMS; do
        echo -e "${YELLOW}  Exportando realm: $realm${NC}"
        docker exec keycloak-dev /opt/keycloak/bin/kc.sh export \
            --dir /tmp/export \
            --realm "$realm" \
            --users realm_file 2>/dev/null || true
        
        # Copiar desde el contenedor
        docker cp "keycloak-dev:/tmp/export/${realm}-realm.json" \
            "${REALM_BACKUP_DIR}/${realm}-realm.json" 2>/dev/null || true
    done
    echo -e "${GREEN}✅ Realms exportados en: $REALM_BACKUP_DIR${NC}"
else
    echo -e "${YELLOW}⚠️  No se encontraron realms adicionales para exportar${NC}"
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
$(docker compose ps)

Versión de Keycloak:
$(docker exec keycloak-dev /opt/keycloak/bin/kc.sh --version 2>/dev/null || echo "N/A")

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
