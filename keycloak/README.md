# Keycloak Lab - Complete Guide

Complete Docker-based Keycloak deployment for Identity & Access Management with comprehensive integration reference.

> **Note:** This document consolidates `SETUP.md` and `COMPONENTS.md` into a single reference guide.

## Table of Contents

### Setup & Configuration
- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Configuration](#configuration)
- [Customization](#customization)
- [Integration Examples](#integration-examples)
- [Operations](#operations)
- [Production Deployment](#production-deployment)
- [Troubleshooting](#troubleshooting)
- [Demo Realm](#demo-realm)

### Integration Components
- [Authentication Protocols](#authentication-protocols)
- [Database Support](#database-support)
- [Directory Integration](#directory-integration)
- [Social Login Providers](#social-login-providers)
- [Email Services](#email-services)
- [Monitoring & Observability](#monitoring--observability)
- [Reverse Proxy & Load Balancing](#reverse-proxy--load-balancing)
- [Cloud Platforms](#cloud-platforms)
- [Secret Management](#secret-management)
- [Security Components](#security-components)
- [Client Libraries](#client-libraries)
- [Admin Tools](#admin-tools)
- [High Availability](#high-availability)
- [Testing Tools](#testing-tools)
- [Performance Tuning](#performance-tuning)

---

## Quick Start

### Development Mode

```bash
cd keycloak
./start-dev.sh
```

**Admin Console**: http://localhost:8080/admin (admin/admin)

### Production Mode

```bash
cd keycloak
./start-prod.sh
```

**Admin Console**: https://localhost:8443/admin (admin/admin)

⚠️ Accept the self-signed certificate warning in your browser.

## Architecture

```
┌─────────────┐    ┌──────────────┐    ┌────────────┐
│   FastAPI   │───▶│   Keycloak   │───▶│ PostgreSQL │
│  (Port 8000)│    │  (Port 8080) │    │ (Port 5432)│
└─────────────┘    └──────────────┘    └────────────┘
       │                   │
       │                   ▼
       │            ┌──────────────┐
       └───────────▶│   Mailhog    │
                    │  (Port 8025) │
                    └──────────────┘
```

## Configuration

### Environment Variables (.env)

> **Note:** Configure these values in `docker/.env` file

```bash
# Admin Credentials
KC_BOOTSTRAP_ADMIN_USERNAME=admin  # Change this in docker/.env
KC_BOOTSTRAP_ADMIN_PASSWORD=admin  # Change this in docker/.env

# Database
KC_DB=postgres
KC_DB_USERNAME=keycloak
KC_DB_PASSWORD=<change_me>  # Configure in docker/.env
POSTGRES_DB=keycloak

# Demo Users (for testing)
DEMO_USER_PASSWORD=<change_me>  # Configure in docker/.env
ADMIN_USER_PASSWORD=<change_me>  # Configure in docker/.env
```

### Execution Modes

**Development** (`start-dev`):
- HTTP enabled, no SSL required
- Cache disabled, theme hot-reload
- Strict hostname validation disabled
- ⚠️ Not for production

**Production** (`start --optimized`):
- HTTPS required, strict hostname
- Optimized build with caching
- Use `keycloak-custom/Dockerfile` for custom builds

## Customization

### Custom Themes

```bash
themes/
└── my-theme/
    ├── login/
    │   ├── theme.properties
    │   └── resources/css/
    ├── account/
    └── email/
```

Mount in docker-compose.yml:
```yaml
volumes:
  - ./themes/my-theme:/opt/keycloak/themes/my-theme
```

### Custom Providers (Extensions)

```bash
providers/
└── my-provider.jar  # Authentication, User Storage, Event Listeners, etc.
```

Types:
- Authentication SPIs
- User Federation (LDAP, REST API)
- Event Listeners
- Protocol Mappers
- Password Policies

Restart after adding: `docker compose restart keycloak-dev`

### Realm Import

```bash
realms/
└── my-realm.json
```

Auto-imported on startup with `--import-realm` flag.

Export existing realm:
```bash
docker exec keycloak-dev /opt/keycloak/bin/kc.sh export \
  --dir /tmp --realm my-realm
docker cp keycloak-dev:/tmp/my-realm-realm.json ./realms/
```

## Integration Examples

### SPA Client (React/Vue/Angular)

**Keycloak Configuration:**
- Client Type: OpenID Connect
- Client Authentication: OFF (public)
- Valid Redirect URIs: `http://localhost:3000/*`
- Web Origins: `http://localhost:3000`

**Code:**
```javascript
import Keycloak from 'keycloak-js';

const keycloak = new Keycloak({
  url: 'http://localhost:8080',
  realm: 'demo-app',
  clientId: 'demo-app-frontend'
});

await keycloak.init({ onLoad: 'login-required' });
```

### Backend API Client

**Keycloak Configuration:**
- Client Type: OpenID Connect
- Client Authentication: ON (confidential)
- Service Accounts: Enabled

**Token Validation (Python/FastAPI):**
```python
from jose import jwt
import requests

# Get JWKS for token validation
jwks_url = f"{keycloak_url}/realms/{realm}/protocol/openid-connect/certs"
jwks = requests.get(jwks_url).json()

# Decode and verify token
payload = jwt.decode(token, jwks, algorithms=["RS256"])
```

## Operations

### Commands

```bash
# Logs
docker compose logs -f keycloak-dev

# Restart
docker compose restart keycloak-dev

# Backup (Prod only)
./backup.sh

# Restore (Prod only)
./restore.sh <timestamp>

# Health check
curl http://localhost:9000/health

# Metrics
curl http://localhost:9000/metrics
```

### Monitoring Stack

Enable Prometheus + Grafana:
```bash
docker compose -f docker/docker-compose.prod.yml -f monitoring/docker-compose.yml up -d
```

Access:
- Grafana: http://localhost:3000 (admin/admin)
- Prometheus: http://localhost:9090

### Production Deployment

1. **Build optimized image:**
```bash
docker build -t keycloak-prod ./keycloak-custom
```

2. **Configure SSL/TLS:**
```yaml
# docker-compose.yml
environment:
  KC_HTTPS_CERTIFICATE_FILE: /opt/keycloak/conf/server.crt
  KC_HTTPS_CERTIFICATE_KEY_FILE: /opt/keycloak/conf/server.key
  KC_HOSTNAME: your-domain.com
  KC_HOSTNAME_STRICT: true
  KC_HTTP_ENABLED: false
```

3. **Use reverse proxy (Nginx/Traefik):**
```nginx
upstream keycloak {
    server keycloak:8080;
}

server {
    listen 443 ssl http2;
    server_name auth.example.com;
    
    ssl_certificate /etc/nginx/certs/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/privkey.pem;
    
    location / {
        proxy_pass http://keycloak;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

4. **Configure database connection pooling:**
```bash
KC_DB_POOL_INITIAL_SIZE=10
KC_DB_POOL_MIN_SIZE=10
KC_DB_POOL_MAX_SIZE=50
```

5. **Enable clustering (HA):**
```bash
KC_CACHE=ispn
KC_CACHE_STACK=kubernetes  # or tcp, udp
```

## Troubleshooting

**Service won't start:**
```bash
docker compose logs keycloak-dev
docker exec keycloak-dev ping postgres
```

**Port conflicts:**
```bash
lsof -i :8080
# Change port in docker-compose.yml
```

**Reset admin password:**
```bash
docker compose down -v  # ⚠️ Deletes all data
docker compose up -d
```

**Import realm fails:**
- Verify JSON syntax
- Check for circular dependencies in client scopes
- Ensure password policies are met for users

## Demo Realm

Pre-configured `demo-app` realm includes:

**Users:**
> **Note:** Passwords are configured in `docker/.env`

- demo-user / Ver `DEMO_USER_PASSWORD` en `docker/.env` (role: user)
- admin-user / Ver `ADMIN_USER_PASSWORD` en `docker/.env` (roles: admin, user)

**Clients:**
- demo-app-frontend (Public SPA client)

**Features:**
- SMTP configured (Mailhog)
- Password policy (12+ chars, mixed case, numbers, special chars)
- Brute force protection enabled

---

# Integration Components

Technical reference for Keycloak ecosystem components and integrations.

## Authentication Protocols

### OpenID Connect (OIDC)
- Identity layer over OAuth 2.0
- ID tokens (JWT) with user claims
- Flows: Authorization Code, Implicit, Hybrid, Client Credentials

### OAuth 2.0
- Authorization framework
- Grant types: Authorization Code, Password, Client Credentials, Refresh Token
- Access tokens for resource access

### SAML 2.0
- XML-based SSO protocol
- Enterprise legacy system integration
- IdP and SP roles

### JWT (JSON Web Tokens)
- Structure: Header.Payload.Signature
- Algorithms: RS256 (RSA), HS256 (HMAC)
- Claims: iss, sub, aud, exp, iat, roles

## Database Support

**Production:**
- PostgreSQL (recommended) - Best performance, JSON support
- MySQL/MariaDB - `KC_DB=mysql`
- MS SQL Server - `KC_DB=mssql`
- Oracle - `KC_DB=oracle`

**Development only:**
- H2 (in-memory)
- dev-file (local file)

## Directory Integration

### LDAP
```bash
# Keycloak Admin Console
User Federation → Add LDAP Provider
- Vendor: Active Directory / Red Hat DS / Other
- Connection URL: ldap://ldap.example.com:389
- Users DN: ou=Users,dc=example,dc=com
- Bind DN: cn=admin,dc=example,dc=com
```

### Active Directory
- Windows-specific LDAP
- Kerberos authentication support
- Group membership mapping

### FreeIPA / Red Hat IDM
- Linux identity management
- Native Keycloak integration

## Social Login Providers

Pre-configured:
- Google, Facebook, GitHub, Twitter, LinkedIn
- Microsoft (Azure AD), Apple, Instagram
- GitLab, Bitbucket, Stack Overflow

Generic support:
- Any OpenID Connect provider
- Any SAML 2.0 IdP
- Custom OAuth 2.0 providers

## Email Services

**Development:**
- Mailhog (included) - Port 1025 (SMTP), 8025 (UI)
- MailDev - Alternative with modern UI

**Production:**
- SendGrid - Cloud email delivery
- AWS SES - Amazon Simple Email Service
- Mailgun - Email API service
- Gmail SMTP - smtp.gmail.com:587 (TLS)
- Office 365 - smtp.office365.com:587

## Monitoring & Observability

### Metrics
**Prometheus:**
- Endpoint: `/metrics` (port 9000)
- JVM metrics, HTTP requests, DB connections, cache stats
- Scrape interval: 15-30s

**Grafana Dashboards:**
- [Keycloak Metrics](https://grafana.com/grafana/dashboards/10441)
- JVM performance, request rates, error rates
- Custom alerts on thresholds

### Logging
**ELK Stack:**
- Elasticsearch: Log storage and indexing
- Logstash: Log processing and filtering
- Kibana: Visualization and queries

**Structured Logging:**
```bash
KC_LOG_CONSOLE_OUTPUT=json
KC_LOG_LEVEL=INFO
```

### Tracing
- Jaeger - Distributed tracing
- Zipkin - Request flow tracking
- OpenTelemetry - Vendor-agnostic observability

## Reverse Proxy & Load Balancing

### Nginx
```nginx
upstream keycloak {
    server keycloak1:8080 max_fails=3 fail_timeout=30s;
    server keycloak2:8080 max_fails=3 fail_timeout=30s;
    keepalive 32;
}

server {
    listen 443 ssl http2;
    ssl_certificate /etc/nginx/certs/cert.pem;
    ssl_certificate_key /etc/nginx/certs/key.pem;
    
    location / {
        proxy_pass http://keycloak;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
    }
}
```

### Traefik
- Automatic service discovery
- Let's Encrypt integration
- Docker/Kubernetes native

### HAProxy
- Layer 4/7 load balancing
- Advanced health checks
- Sticky sessions

### Kong
- API Gateway functionality
- Rate limiting, authentication plugins
- Metrics and logging

## Cloud Platforms

### Kubernetes
**Keycloak Operator:**
```bash
kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/main/kubernetes/keycloaks.k8s.keycloak.org-v1.yml
```

**Helm Chart:**
```bash
helm repo add codecentric https://codecentric.github.io/helm-charts
helm install keycloak codecentric/keycloak \
  --set replicas=3 \
  --set postgresql.enabled=true
```

**Features:**
- Auto-scaling (HPA)
- Rolling updates
- ConfigMaps for configuration
- Secrets for credentials

### Cloud Providers

**AWS:**
- ECS/EKS for containers
- RDS PostgreSQL for database
- ALB for load balancing
- Route 53 for DNS
- ACM for SSL certificates

**Azure:**
- AKS for Kubernetes
- Azure Database for PostgreSQL
- Application Gateway
- Azure DNS
- Key Vault for secrets

**GCP:**
- GKE for Kubernetes
- Cloud SQL PostgreSQL
- Cloud Load Balancing
- Cloud DNS
- Secret Manager

## Secret Management

### HashiCorp Vault
```bash
KC_VAULT=hashicorp
KC_VAULT_URL=http://vault:8200
KC_VAULT_TOKEN=<token>
```

**Features:**
- Dynamic secrets
- Automatic rotation
- Audit logging

### Cloud Secrets
- AWS Secrets Manager
- Azure Key Vault
- GCP Secret Manager
- Kubernetes Secrets + External Secrets Operator

## Security Components

### Web Application Firewall (WAF)
- ModSecurity (Nginx/Apache)
- AWS WAF
- Cloudflare WAF
- OWASP Core Rule Set

### DDoS Protection
- Cloudflare
- AWS Shield
- Akamai

### Rate Limiting
```nginx
# Nginx
limit_req_zone $binary_remote_addr zone=keycloak:10m rate=10r/s;
limit_req zone=keycloak burst=20 nodelay;
```

Keycloak built-in:
```json
{
  "bruteForceProtected": true,
  "permanentLockout": false,
  "maxFailureWaitSeconds": 900,
  "minimumQuickLoginWaitSeconds": 60,
  "waitIncrementSeconds": 60,
  "quickLoginCheckMilliSeconds": 1000,
  "maxDeltaTimeSeconds": 43200,
  "failureFactor": 30
}
```

### MFA/2FA
- **TOTP:** Google Authenticator, Authy
- **WebAuthn/FIDO2:** Hardware keys (YubiKey)
- **SMS:** Twilio, AWS SNS integration
- **Email:** OTP via SMTP

## Client Libraries

### JavaScript/TypeScript
```bash
npm install keycloak-js
npm install @react-keycloak/web
npm install keycloak-angular
```

### Java
```xml
<dependency>
    <groupId>org.keycloak</groupId>
    <artifactId>keycloak-spring-boot-starter</artifactId>
</dependency>
```

### Python
```bash
pip install python-keycloak
pip install python-jose[cryptography]  # JWT validation
```

### .NET
```bash
dotnet add package Keycloak.AuthServices.Authentication
```

### Go
```bash
go get github.com/Nerzal/gocloak/v13
```

## Admin Tools

### CLI (kcadm)
```bash
# Authenticate
kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user admin

# Create realm
kcadm.sh create realms -s realm=myrealm -s enabled=true

# Create user
kcadm.sh create users -r myrealm \
  -s username=user1 \
  -s enabled=true

# Set password
kcadm.sh set-password -r myrealm \
  --username user1 \
  --new-password password123
```

### Keycloak Config CLI
- Configuration as code
- GitOps-friendly
- Automated imports

### Terraform Provider
```hcl
provider "keycloak" {
  client_id = "terraform"
  url       = "http://localhost:8080"
}

resource "keycloak_realm" "myrealm" {
  realm   = "myrealm"
  enabled = true
}

resource "keycloak_user" "user1" {
  realm_id = keycloak_realm.myrealm.id
  username = "user1"
  enabled  = true
}
```

## High Availability

### Clustering
```bash
# Infinispan cache configuration
KC_CACHE=ispn
KC_CACHE_STACK=kubernetes  # or tcp, udp

# Database-based coordination
KC_DB_POOL_MIN_SIZE=10
KC_DB_POOL_MAX_SIZE=100
```

### Session Replication
- Distributed cache (Infinispan)
- Sticky sessions (load balancer)
- External session store (Redis - via custom SPI)

### Backup Strategy
1. Database backups (automated)
2. Realm exports (configuration)
3. Theme and provider backups
4. Disaster recovery testing

## Testing Tools

- **Postman/Insomnia:** OAuth/OIDC flow testing
- **jwt.io:** Token decoding and validation
- **OAuth 2.0 Playground:** Flow simulation
- **Testcontainers:** Automated integration tests

## Performance Tuning

### JVM Options
```bash
JAVA_OPTS_KC_HEAP="-Xms2g -Xmx4g"
JAVA_OPTS="-XX:+UseG1GC -XX:MaxGCPauseMillis=100"
```

### Database
- Connection pooling (10-50 connections per instance)
- Read replicas for user queries
- Indexes on frequently queried fields

### Caching
- Browser cache headers (static assets)
- CDN for themes and resources
- Redis for distributed sessions (custom)

### Horizontal Scaling
- Multiple Keycloak instances behind load balancer
- Database read replicas
- Shared Infinispan cache cluster

---

## Resources

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Server Admin Guide](https://www.keycloak.org/docs/latest/server_admin/)
- [Securing Apps](https://www.keycloak.org/docs/latest/securing_apps/)
