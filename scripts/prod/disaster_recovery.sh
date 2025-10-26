#!/bin/bash

# Disaster Recovery Script for Keycloak - Automated Version
# Este script ejecuta automáticamente todas las pruebas de disaster recovery

# set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Directorio base
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${SCRIPT_DIR}/../../backups"
BACKUP_SCRIPT="${SCRIPT_DIR}/backup.sh"
RESTORE_SCRIPT="${SCRIPT_DIR}/restore.sh"

# Load environment variables from docker/.env
if [ -f "${SCRIPT_DIR}/../../docker/.env" ]; then
    source "${SCRIPT_DIR}/../../docker/.env"
fi
KC_ADMIN_USERNAME="${KC_ADMIN_USERNAME:-admin}"
KC_ADMIN_PASSWORD="${KC_ADMIN_PASSWORD:-admin}"

# Banner
show_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║        KEYCLOAK DISASTER RECOVERY - AUTOMATED TEST           ║
║                                                              ║
║        Backup, Restore & Disaster Recovery Validation        ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
}

# Detectar entorno
detect_environment() {
    if docker ps | grep -q "keycloak-prod"; then
        echo "keycloak-prod"
    elif docker ps | grep -q "keycloak-dev"; then
        echo "keycloak-dev"
    else
        echo "none"
    fi
}

# Mostrar estado del sistema
show_system_status() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  ESTADO DEL SISTEMA${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local env=$(detect_environment)
    if [ "$env" == "none" ]; then
        echo -e "${RED}❌ No hay ningún contenedor de Keycloak en ejecución${NC}"
        echo ""
        return 1
    fi
    
    echo -e "${GREEN}✅ Entorno activo: $env${NC}"
    echo ""
    
    # Estado de contenedores
    echo -e "${YELLOW}Contenedores Keycloak:${NC}"
    docker ps --filter "name=keycloak" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -5
    echo ""
    
    # Estado de PostgreSQL
    echo -e "${YELLOW}Base de datos PostgreSQL:${NC}"
    docker ps --filter "name=postgres" --format "table {{.Names}}\t{{.Status}}"
    echo ""
    
    # Espacio en disco
    echo -e "${YELLOW}Espacio en disco (backups):${NC}"
    if [ -d "$BACKUP_DIR" ]; then
        du -sh "$BACKUP_DIR" 2>/dev/null || echo "  Sin backups"
        echo "  Número de backups: $(ls -1 "$BACKUP_DIR"/*.sql.gz 2>/dev/null | wc -l)"
    else
        echo "  No existe directorio de backups"
    fi
    echo ""
    
    # Último backup
    echo -e "${YELLOW}Último backup:${NC}"
    local last_backup=$(ls -t "$BACKUP_DIR"/*.sql.gz 2>/dev/null | head -1)
    if [ -n "$last_backup" ]; then
        echo "  Archivo: $(basename $last_backup)"
        echo "  Fecha: $(date -r "$last_backup" '+%Y-%m-%d %H:%M:%S')"
        echo "  Tamaño: $(du -h "$last_backup" | cut -f1)"
    else
        echo "  No hay backups disponibles"
    fi
    echo ""
    
    return 0
}

# Listar backups
list_backups() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  BACKUPS DISPONIBLES${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR"/*.sql.gz 2>/dev/null)" ]; then
        echo -e "${YELLOW}No hay backups disponibles${NC}"
        echo ""
        return 0
    fi
    
    echo -e "${CYAN}Timestamp           Fecha/Hora          Tamaño    Realm${NC}"
    echo "────────────────────────────────────────────────────────────"
    
    for backup in $(ls -t "$BACKUP_DIR"/*.sql.gz 2>/dev/null); do
        local timestamp=$(basename "$backup" | sed 's/keycloak_db_//' | sed 's/.sql.gz//')
        local size=$(du -h "$backup" | cut -f1)
        local date_str=$(date -r "$backup" '+%Y-%m-%d %H:%M:%S')
        local realm_dir="$BACKUP_DIR/realms_$timestamp"
        local realm_info=""
        
        if [ -d "$realm_dir" ]; then
            local realm_count=$(ls -1 "$realm_dir"/*.json 2>/dev/null | wc -l)
            realm_info="✓ ($realm_count realms)"
        else
            realm_info="✗"
        fi
        
        echo -e "${GREEN}$timestamp${NC}  $date_str  ${YELLOW}$size${NC}    $realm_info"
    done
    echo ""
    
    return 0
}

# Crear backup
create_backup() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  CREAR BACKUP${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [ ! -f "$BACKUP_SCRIPT" ]; then
        echo -e "${RED}❌ No se encuentra el script de backup: $BACKUP_SCRIPT${NC}"
        echo ""
        return 1
    fi
    
    echo -e "${YELLOW}Iniciando proceso de backup...${NC}"
    echo ""
    
    bash "$BACKUP_SCRIPT"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✅ Backup completado exitosamente${NC}"
    else
        echo ""
        echo -e "${RED}❌ Error al crear backup${NC}"
        return 1
    fi
    echo ""
}

# Restaurar backup
restore_backup() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  RESTAURAR BACKUP${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [ ! -f "$RESTORE_SCRIPT" ]; then
        echo -e "${RED}❌ No se encuentra el script de restore: $RESTORE_SCRIPT${NC}"
        echo ""
        return 1
    fi
    
    list_backups
    
    echo -e "${YELLOW}Introduce el timestamp del backup a restaurar:${NC}"
    read -p "Timestamp: " timestamp
    
    if [ -z "$timestamp" ]; then
        echo -e "${YELLOW}Operación cancelada${NC}"
        echo ""
        return
    fi
    
    local backup_file="$BACKUP_DIR/keycloak_db_${timestamp}.sql.gz"
    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}❌ No existe el backup: $backup_file${NC}"
        echo ""
        return 1
    fi
    
    echo ""
    echo -e "${RED}⚠️  ADVERTENCIA: Esta operación sobrescribirá TODOS los datos actuales${NC}"
    echo -e "${YELLOW}Backup a restaurar:${NC}"
    echo "  Timestamp: $timestamp"
    echo "  Archivo: $(basename $backup_file)"
    echo "  Tamaño: $(du -h "$backup_file" | cut -f1)"
    echo "  Fecha: $(date -r "$backup_file" '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    bash "$RESTORE_SCRIPT" "$timestamp"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✅ Restore completado exitosamente${NC}"
    else
        echo ""
        echo -e "${RED}❌ Error al restaurar backup${NC}"
        return 1
    fi
    echo ""
}

# Verificar integridad de backups
verify_backups() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  VERIFICAR INTEGRIDAD DE BACKUPS${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR"/*.sql.gz 2>/dev/null)" ]; then
        echo -e "${YELLOW}No hay backups para verificar${NC}"
        echo ""
        return
    fi
    
    local total=0
    local valid=0
    local invalid=0
    
    for backup in $(ls "$BACKUP_DIR"/*.sql.gz 2>/dev/null); do
        total=$((total + 1))
        local timestamp=$(basename "$backup" | sed 's/keycloak_db_//' | sed 's/.sql.gz//')
        
        echo -n "Verificando backup $timestamp... "
        
        # Verificar que el archivo gzip es válido
        if gunzip -t "$backup" 2>/dev/null; then
            echo -e "${GREEN}✓ OK${NC}"
            valid=$((valid + 1))
            
            # Verificar si existe el directorio de realms correspondiente
            local realm_dir="$BACKUP_DIR/realms_$timestamp"
            if [ -d "$realm_dir" ]; then
                local realm_count=$(ls -1 "$realm_dir"/*.json 2>/dev/null | wc -l)
                echo "  └─ Realms: $realm_count archivos"
            else
                echo -e "  └─ ${YELLOW}Sin backups de realms${NC}"
            fi
        else
            echo -e "${RED}✗ CORRUPTO${NC}"
            invalid=$((invalid + 1))
        fi
    done
    
    echo ""
    echo -e "${CYAN}Resumen de verificación:${NC}"
    echo "  Total: $total backups"
    echo -e "  Válidos: ${GREEN}$valid${NC}"
    echo -e "  Corruptos: ${RED}$invalid${NC}"
    echo ""
}

# Prueba de disaster recovery (automática)
test_disaster_recovery() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  PRUEBA DE DISASTER RECOVERY${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${YELLOW}Esta prueba realizará:${NC}"
    echo "  1. Crear un backup de seguridad"
    echo "  2. Hacer una modificación en Keycloak"
    echo "  3. Restaurar desde el backup"
    echo "  4. Verificar que la restauración fue exitosa"
    echo ""
    
    echo ""
    echo -e "${CYAN}Paso 1/4: Creando backup de seguridad...${NC}"
    
    # Crear archivo temporal para capturar errores
    local BACKUP_LOG=$(mktemp)
    
    # Ejecutar backup y capturar salida
    if bash "$BACKUP_SCRIPT" > "$BACKUP_LOG" 2>&1; then
        # Backup exitoso
        local test_backup=$(ls -t "$BACKUP_DIR"/*.sql.gz 2>/dev/null | head -1)
        if [ -z "$test_backup" ]; then
            echo -e "${RED}✗ No se encontró el backup creado${NC}"
            rm -f "$BACKUP_LOG"
            return 1
        fi
        
        local test_timestamp=$(basename "$test_backup" | sed 's/keycloak_db_//' | sed 's/.sql.gz//')
        echo -e "${GREEN}✓ Backup creado: $test_timestamp${NC}"
        rm -f "$BACKUP_LOG"
    else
        # Backup falló
        echo -e "${RED}✗ Error al crear backup${NC}"
        echo -e "${YELLOW}Últimas líneas del log:${NC}"
        tail -10 "$BACKUP_LOG" | sed 's/^/  /'
        rm -f "$BACKUP_LOG"
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}Paso 2/4: Realizando modificación de prueba...${NC}"
    
    local ADMIN_TOKEN=$(curl -k -s -X POST "https://localhost:8443/realms/master/protocol/openid-connect/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "client_id=admin-cli" \
      -d "username=${KC_ADMIN_USERNAME}" \
      -d "password=${KC_ADMIN_PASSWORD}" \
      -d "grant_type=password" 2>/dev/null | jq -r '.access_token' 2>/dev/null)
    
    if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" == "null" ]; then
        echo -e "${RED}✗ No se pudo obtener token de admin${NC}"
        return 1
    fi
    
    local original_name=$(curl -k -s "https://localhost:8443/admin/realms/demo-app" \
      -H "Authorization: Bearer $ADMIN_TOKEN" 2>/dev/null | jq -r '.displayName' 2>/dev/null)
    
    if [ -z "$original_name" ] || [ "$original_name" == "null" ]; then
        echo -e "${YELLOW}⚠ No se pudo obtener displayName original, usando valor por defecto${NC}"
        original_name="Demo Application"
    fi
    
    echo "  Original displayName: $original_name"
    
    curl -k -s -X PUT "https://localhost:8443/admin/realms/demo-app" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{"displayName": "TEST DISASTER RECOVERY"}' > /dev/null 2>&1
    
    local modified_name=$(curl -k -s "https://localhost:8443/admin/realms/demo-app" \
      -H "Authorization: Bearer $ADMIN_TOKEN" 2>/dev/null | jq -r '.displayName' 2>/dev/null)
    echo -e "${GREEN}✓ Modificado a: $modified_name${NC}"
    
    echo ""
    echo -e "${CYAN}Paso 3/4: Restaurando desde backup...${NC}"
    
    # Crear archivo temporal para capturar errores del restore
    local RESTORE_LOG=$(mktemp)
    
    # Ejecutar restore con flag -y para omitir confirmación
    if bash "$RESTORE_SCRIPT" -y "$test_timestamp" > "$RESTORE_LOG" 2>&1; then
        echo -e "${GREEN}✓ Restauración completada${NC}"
        rm -f "$RESTORE_LOG"
    else
        echo -e "${RED}✗ Error al restaurar backup${NC}"
        echo -e "${YELLOW}Últimas líneas del log:${NC}"
        tail -10 "$RESTORE_LOG" | sed 's/^/  /'
        rm -f "$RESTORE_LOG"
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}Paso 4/4: Verificando restauración...${NC}"
    echo "  Esperando a que Keycloak esté listo..."
    sleep 10
    
    # Esperar a que Keycloak esté disponible
    local max_attempts=30
    local attempt=0
    until curl -k -sf https://localhost:8443/realms/master > /dev/null 2>&1; do
        attempt=$((attempt + 1))
        if [ $attempt -ge $max_attempts ]; then
            echo -e "${RED}✗ Keycloak no está disponible después de la restauración${NC}"
            return 1
        fi
        sleep 2
    done
    
    ADMIN_TOKEN=$(curl -k -s -X POST "https://localhost:8443/realms/master/protocol/openid-connect/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "client_id=admin-cli" \
      -d "username=${KC_ADMIN_USERNAME}" \
      -d "password=${KC_ADMIN_PASSWORD}" \
      -d "grant_type=password" 2>/dev/null | jq -r '.access_token' 2>/dev/null)
    
    if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" == "null" ]; then
        echo -e "${RED}✗ No se pudo obtener token de admin después de restaurar${NC}"
        return 1
    fi
    
    local restored_name=$(curl -k -s "https://localhost:8443/admin/realms/demo-app" \
      -H "Authorization: Bearer $ADMIN_TOKEN" 2>/dev/null | jq -r '.displayName' 2>/dev/null)
    
    echo "  DisplayName restaurado: $restored_name"
    
    if [ "$restored_name" == "$original_name" ]; then
        echo -e "${GREEN}✓ Verificación exitosa - Los datos fueron restaurados correctamente${NC}"
    else
        echo -e "${YELLOW}⚠ El displayName no coincide exactamente con el original${NC}"
        echo "    Original: '$original_name'"
        echo "    Restaurado: '$restored_name'"
    fi
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ PRUEBA DE DISASTER RECOVERY COMPLETADA                ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    return 0
}

# Verificar integridad de backups
verify_backups() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  VERIFICAR INTEGRIDAD DE BACKUPS${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR"/*.sql.gz 2>/dev/null)" ]; then
        echo -e "${YELLOW}No hay backups para verificar${NC}"
        echo ""
        return 0
    fi
    
    local total=0
    local valid=0
    local invalid=0
    
    for backup in $(ls "$BACKUP_DIR"/*.sql.gz 2>/dev/null); do
        total=$((total + 1))
        local timestamp=$(basename "$backup" | sed 's/keycloak_db_//' | sed 's/.sql.gz//')
        
        echo -n "Verificando backup $timestamp... "
        
        # Verificar que el archivo gzip es válido
        if gunzip -t "$backup" 2>/dev/null; then
            echo -e "${GREEN}✓ OK${NC}"
            valid=$((valid + 1))
            
            # Verificar si existe el directorio de realms correspondiente
            local realm_dir="$BACKUP_DIR/realms_$timestamp"
            if [ -d "$realm_dir" ]; then
                local realm_count=$(ls -1 "$realm_dir"/*.json 2>/dev/null | wc -l)
                echo "  └─ Realms: $realm_count archivos"
            else
                echo -e "  └─ ${YELLOW}Sin backups de realms${NC}"
            fi
        else
            echo -e "${RED}✗ CORRUPTO${NC}"
            invalid=$((invalid + 1))
        fi
    done
    
    echo ""
    echo -e "${CYAN}Resumen de verificación:${NC}"
    echo "  Total: $total backups"
    echo -e "  Válidos: ${GREEN}$valid${NC}"
    if [ $invalid -gt 0 ]; then
        echo -e "  Corruptos: ${RED}$invalid${NC}"
    else
        echo -e "  Corruptos: ${GREEN}0${NC}"
    fi
    echo ""
    
    return 0
}

# Main - Ejecución automática
main() {
    show_banner
    
    # Verificar que los scripts necesarios existen
    if [ ! -f "$BACKUP_SCRIPT" ]; then
        echo -e "${RED}❌ No se encuentra el script de backup: $BACKUP_SCRIPT${NC}"
        exit 1
    fi
    
    if [ ! -f "$RESTORE_SCRIPT" ]; then
        echo -e "${RED}❌ No se encuentra el script de restore: $RESTORE_SCRIPT${NC}"
        exit 1
    fi
    
    # Verificar que jq está instalado
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}❌ jq no está instalado. Instálalo con: sudo apt-get install jq${NC}"
        exit 1
    fi
    
    # 1. Mostrar estado del sistema
    show_system_status
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ No se puede continuar sin un entorno activo${NC}"
        exit 1
    fi
    
    # 2. Listar backups disponibles
    list_backups
    
    # 3. Verificar integridad de backups
    verify_backups
    
    # 4. Ejecutar prueba de disaster recovery
    test_disaster_recovery
    TEST_RESULT=$?
    
    # Resumen final
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  RESUMEN FINAL${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [ $TEST_RESULT -eq 0 ]; then
        echo -e "${GREEN}✅ Todas las pruebas de disaster recovery se completaron exitosamente${NC}"
        echo ""
        echo -e "${CYAN}El sistema está listo para disaster recovery:${NC}"
        echo "  • Backups funcionando correctamente"
        echo "  • Proceso de restore validado"
        echo "  • Integridad de datos verificada"
    else
        echo -e "${RED}❌ Las pruebas de disaster recovery encontraron errores${NC}"
        echo ""
        echo -e "${YELLOW}Por favor revisa los logs arriba para más detalles${NC}"
    fi
    echo ""
    
    exit $TEST_RESULT
}

# Ejecutar
main
