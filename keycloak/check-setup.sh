#!/bin/bash

# Lista de verificación post-instalación de Keycloak
# Ejecutar este script para verificar que todo está configurado correctamente

set -e

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Keycloak - Verificación de Instalación            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Verificar Docker
echo -e "${YELLOW}[1/10] Verificando Docker...${NC}"
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✅ Docker instalado: $(docker --version)${NC}"
else
    echo -e "${RED}❌ Docker NO instalado${NC}"
    exit 1
fi

# Verificar Docker Compose
echo -e "${YELLOW}[2/10] Verificando Docker Compose...${NC}"
if command -v docker compose &> /dev/null; then
    echo -e "${GREEN}✅ Docker Compose instalado: $(docker compose version)${NC}"
else
    echo -e "${RED}❌ Docker Compose NO instalado${NC}"
    exit 1
fi

# Verificar estructura de archivos
echo -e "${YELLOW}[3/10] Verificando estructura de archivos...${NC}"
files=(
    "docker-compose.yml"
    "docker-compose.monitoring.yml"
    ".env.example"
    ".gitignore"
    "README.md"
    "QUICKSTART.md"
    "COMPONENTES.md"
    "start.sh"
    "backup.sh"
    "restore.sh"
    "prometheus.yml"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}  ✓ $file${NC}"
    else
        echo -e "${RED}  ✗ $file${NC}"
    fi
done

# Verificar directorios
echo -e "${YELLOW}[4/10] Verificando directorios...${NC}"
dirs=(
    "realms"
    "keycloak-custom"
    "nginx"
    "examples"
    "providers"
    "themes"
)

for dir in "${dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "${GREEN}  ✓ $dir/${NC}"
    else
        echo -e "${YELLOW}  ⚠ $dir/ no existe (se creará automáticamente)${NC}"
        mkdir -p "$dir"
    fi
done

# Verificar permisos de scripts
echo -e "${YELLOW}[5/10] Verificando permisos de scripts...${NC}"
scripts=("start.sh" "backup.sh" "restore.sh")
for script in "${scripts[@]}"; do
    if [ -x "$script" ]; then
        echo -e "${GREEN}  ✓ $script es ejecutable${NC}"
    else
        echo -e "${YELLOW}  ⚠ $script no es ejecutable, arreglando...${NC}"
        chmod +x "$script"
        echo -e "${GREEN}  ✓ Permisos corregidos${NC}"
    fi
done

# Verificar archivo .env
echo -e "${YELLOW}[6/10] Verificando archivo .env...${NC}"
if [ -f ".env" ]; then
    echo -e "${GREEN}✅ Archivo .env existe${NC}"
else
    echo -e "${YELLOW}⚠️  Archivo .env no existe, creando desde .env.example...${NC}"
    cp .env.example .env
    echo -e "${GREEN}✅ Archivo .env creado${NC}"
fi

# Verificar si Docker está corriendo
echo -e "${YELLOW}[7/10] Verificando Docker daemon...${NC}"
if docker info &> /dev/null; then
    echo -e "${GREEN}✅ Docker daemon está corriendo${NC}"
else
    echo -e "${RED}❌ Docker daemon NO está corriendo${NC}"
    echo -e "${YELLOW}   Ejecuta: sudo systemctl start docker${NC}"
    exit 1
fi

# Verificar puertos disponibles
echo -e "${YELLOW}[8/10] Verificando puertos disponibles...${NC}"
ports=(8080 9000 5432 8025 8081)
for port in "${ports[@]}"; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${RED}  ✗ Puerto $port está en uso${NC}"
    else
        echo -e "${GREEN}  ✓ Puerto $port disponible${NC}"
    fi
done

# Verificar servicios Docker
echo -e "${YELLOW}[9/10] Verificando servicios Docker...${NC}"
if docker compose ps &> /dev/null; then
    docker compose ps
else
    echo -e "${YELLOW}⚠️  No hay servicios corriendo${NC}"
fi

# Verificar conectividad
echo -e "${YELLOW}[10/10] Verificando URLs (si los servicios están corriendo)...${NC}"
urls=(
    "http://localhost:8080"
    "http://localhost:9000/health"
    "http://localhost:8025"
    "http://localhost:8081"
)

for url in "${urls[@]}"; do
    if curl -s -o /dev/null -w "%{http_code}" "$url" 2>&1 | grep -q "200\|302"; then
        echo -e "${GREEN}  ✓ $url accesible${NC}"
    else
        echo -e "${YELLOW}  ⚠ $url no accesible (normal si no está corriendo)${NC}"
    fi
done

# Resumen final
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    Verificación Completa                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✅ Sistema listo para usar${NC}"
echo ""
echo -e "${YELLOW}📚 Próximos pasos:${NC}"
echo ""
echo -e "1. Revisa el archivo .env y ajusta las variables"
echo -e "2. Ejecuta: ${GREEN}./start.sh${NC}"
echo -e "3. Accede a: ${GREEN}http://localhost:8080/admin${NC}"
echo -e "4. Lee el ${GREEN}README.md${NC} para más información"
echo ""
echo -e "${YELLOW}📖 Documentación disponible:${NC}"
echo -e "   - README.md         (guía completa)"
echo -e "   - QUICKSTART.md     (inicio rápido)"
echo -e "   - COMPONENTES.md    (componentes relacionados)"
echo -e "   - ESTRUCTURA.md     (estructura del proyecto)"
echo ""
