FROM quay.io/keycloak/keycloak:26.0.7 AS builder

# Configuración de features y optimizaciones
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true
ENV KC_DB=postgres
ENV KC_FEATURES=token-exchange,admin-fine-grained-authz

# Copiar providers personalizados (si existen)
# COPY providers/*.jar /opt/keycloak/providers/

# Copiar temas personalizados (si existen)
# COPY themes/ /opt/keycloak/themes/

WORKDIR /opt/keycloak

# Generar certificado auto-firmado para desarrollo
# En producción, reemplazar con certificados válidos
RUN keytool -genkeypair -storepass password -storetype PKCS12 \
    -keyalg RSA -keysize 2048 \
    -dname "CN=keycloak,OU=Development,O=MyOrg,L=City,ST=State,C=US" \
    -alias server \
    -ext "SAN:c=DNS:localhost,DNS:keycloak,IP:127.0.0.1" \
    -keystore conf/server.keystore

# Build optimizado - esto mejora significativamente el tiempo de inicio
RUN /opt/keycloak/bin/kc.sh build

# ==========================================
# Imagen final optimizada
# ==========================================
FROM quay.io/keycloak/keycloak:26.0.7

# Copiar el build optimizado
COPY --from=builder /opt/keycloak/ /opt/keycloak/

# Variables de entorno para producción
# Estas se pueden sobrescribir en docker compose o k8s
ENV KC_DB=postgres
ENV KC_HOSTNAME=localhost
ENV KC_HTTP_ENABLED=true

# Metadata
LABEL maintainer="DevOps Team"
LABEL description="Keycloak optimizado para producción"
LABEL version="26.0.7"

# El entrypoint permite ejecutar cualquier comando de kc.sh
ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]

# Por defecto, iniciar en modo optimizado
CMD ["start", "--optimized"]
