# Build stage
FROM python:3.11-slim as builder

WORKDIR /app

# Instalar dependencias
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Runtime stage
FROM python:3.11-slim

WORKDIR /app

# Copiar dependencias desde build stage
COPY --from=builder /root/.local /root/.local

# Copiar código de la aplicación
COPY main.py .

# Asegurar que los scripts de usuario estén en el PATH
ENV PATH=/root/.local/bin:$PATH

# Exponer puerto
EXPOSE 8000

# Variables de entorno (pueden ser sobrescritas)
ENV KEYCLOAK_URL=http://keycloak-dev:8080
ENV KEYCLOAK_REALM=demo-app
ENV KEYCLOAK_CLIENT_ID=demo-app-frontend

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8000/health')"

# Comando para iniciar la aplicación
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
