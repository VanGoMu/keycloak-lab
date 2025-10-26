#!/bin/bash

# Script para iniciar la aplicación FastAPI de forma local (sin Docker)

set -e

echo "=================================================="
echo "🚀 FastAPI + Keycloak - Inicio Rápido"
echo "=================================================="
echo ""

# Verificar que Keycloak esté corriendo
echo "🔍 Verificando que Keycloak esté disponible..."
if ! curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo "❌ Error: Keycloak no está corriendo en localhost:8080"
    echo ""
    echo "Por favor inicia Keycloak primero:"
    echo "  cd ../keycloak && docker compose up -d"
    exit 1
fi

echo "✅ Keycloak está corriendo"
echo ""

# Verificar Python
echo "🔍 Verificando Python..."
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: Python 3 no está instalado"
    exit 1
fi

PYTHON_VERSION=$(python3 --version)
echo "✅ $PYTHON_VERSION encontrado"
echo ""

# Crear entorno virtual si no existe
if [ ! -d "venv" ]; then
    echo "📦 Creando entorno virtual..."
    python3 -m venv venv
    echo "✅ Entorno virtual creado"
else
    echo "✅ Entorno virtual ya existe"
fi
echo ""

# Activar entorno virtual
echo "🔧 Activando entorno virtual..."
source venv/bin/activate
echo ""

# Instalar dependencias
echo "📦 Instalando dependencias..."
pip install --quiet --upgrade pip
pip install --quiet -r requirements.txt
echo "✅ Dependencias instaladas"
echo ""

# Verificar variables de entorno
if [ ! -f ".env" ]; then
    echo "⚠️  Archivo .env no encontrado, usando valores por defecto"
fi

echo "=================================================="
echo "🎉 Todo listo! Iniciando FastAPI..."
echo "=================================================="
echo ""
echo "📍 La aplicación estará disponible en:"
echo "   • API: http://localhost:8000"
echo "   • Docs: http://localhost:8000/docs"
echo "   • Interfaz: http://localhost:8000"
echo ""
echo "👤 Usuarios de prueba:"
echo "   • demo-user / \$DEMO_USER_PASSWORD (ver docker/.env) (rol: user)"
echo "   • admin-user / \$ADMIN_USER_PASSWORD (ver docker/.env) (roles: admin, user)"
echo ""
echo "Press Ctrl+C para detener el servidor"
echo "=================================================="
echo ""

# Iniciar FastAPI
python main.py
