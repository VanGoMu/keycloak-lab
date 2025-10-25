# Keycloak Setup Guide

Complete Docker-based Keycloak deployment for Identity & Access Management.

## Quick Start

```bash
cd keycloak
./start.sh
```

**Admin Console**: http://localhost:8080/admin (admin/admin)

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

```bash
# Admin Credentials
KC_BOOTSTRAP_ADMIN_USERNAME=admin
KC_BOOTSTRAP_ADMIN_PASSWORD=admin

# Database
KC_DB=postgres
KC_DB_USERNAME=keycloak
KC_DB_PASSWORD=<change_me>
POSTGRES_DB=keycloak

# Network
KC_HOSTNAME=localhost
KC_HTTP_ENABLED=true  # Dev only - use HTTPS in production
KC_PROXY=edge

# Features
KC_HEALTH_ENABLED=true
KC_METRICS_ENABLED=true
KC_FEATURES=token-exchange,admin-fine-grained-authz
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

# Backup
./backup.sh

# Restore
./restore.sh <timestamp>

# Health check
curl http://localhost:9000/health

# Metrics
curl http://localhost:9000/metrics
```

### Monitoring Stack

Enable Prometheus + Grafana:
```bash
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d
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
- demo-user / Demo@User123 (role: user)
- admin-user / Admin@User123 (roles: admin, user)

**Clients:**
- demo-app-frontend (Public SPA client)

**Features:**
- SMTP configured (Mailhog)
- Password policy (12+ chars, mixed case, numbers, special chars)
- Brute force protection enabled

## Resources

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Server Admin Guide](https://www.keycloak.org/docs/latest/server_admin/)
- [Securing Apps](https://www.keycloak.org/docs/latest/securing_apps/)
