# Keycloak Identity & Access Management - Docker Environment

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Keycloak](https://img.shields.io/badge/Keycloak-26.0.7-blue)](https://www.keycloak.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-blue)](https://www.postgresql.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-Latest-green)](https://fastapi.tiangolo.com/)

Complete Docker-based Keycloak setup with authentication examples and comprehensive documentation.

## 🚀 Quick Start

```bash
# 1. Clone el repositorio (si aún no lo has hecho)
cd keycloak-lab

# 2. Inicia Keycloak
cd keycloak
./start.sh

# 3. Verifica que esté funcionando
curl http://localhost:9000/health
# Expected: {"status":"UP","checks":[...]}

# 4. Accede a la consola de admin
# URL: http://localhost:8080/admin
# Credenciales: admin / admin
```

**✅ Verificación Rápida:**
- [ ] Keycloak Admin Console accesible → http://localhost:8080/admin
- [ ] Mailhog UI funcionando → http://localhost:8025
- [ ] FastAPI app respondiendo → http://localhost:8000
- [ ] Health check OK → `curl http://localhost:9000/health`

## 📦 What's Included

### Core Services

| Service | Version | Purpose | Ports |
|---------|---------|---------|-------|
| **Keycloak** | 26.0.7 | Identity & Access Management | 8080 (HTTP), 9000 (Metrics) |
| **PostgreSQL** | 16-alpine | Persistent database | 5432 |
| **Mailhog** | latest | SMTP testing server | 1025 (SMTP), 8025 (UI) |
| **Adminer** | latest | Database management UI | 8081 |
| **FastAPI Demo** | Custom | Python integration example | 8000 |

### Features Out-of-the-Box
- ✅ Pre-configured `demo-app` realm with test users
- ✅ OAuth2/OIDC clients ready to use
- ✅ SMTP configured for email testing (Mailhog)
- ✅ Health checks and Prometheus metrics enabled
- ✅ Automated backup/restore scripts
- ✅ Role-based access control (RBAC) examples

### Optional Monitoring Stack
- **Prometheus** - Metrics collection and storage
- **Grafana** - Metrics visualization and dashboards
- **PostgreSQL Exporter** - Database metrics

**Enable with:**
```bash
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d
```

## 📚 Documentation

### Main Documentation (Keycloak Setup)
Located in `/keycloak/` directory:

| Document | Description |
|----------|-------------|
| [README.md](keycloak/README.md) | Complete setup guide with integration components reference (merged SETUP.md + COMPONENTS.md) |

### FastAPI Integration Example
Located in `/fast-api-app/` directory:

| Document | Description |
|----------|-------------|
| [README.md](fast-api-app/README.md) | FastAPI + Keycloak integration guide with OAuth2/OIDC, role-based access control, and token validation |

## 🎯 Key Features

### Security & Authentication
- ✅ Single Sign-On (SSO)
- ✅ OAuth 2.0 / OpenID Connect / SAML 2.0
- ✅ Multi-Factor Authentication (MFA)
- ✅ Social Login (Google, GitHub, Facebook, etc.)
- ✅ User Federation (LDAP/Active Directory)
- ✅ Fine-grained Authorization

### Development & Operations
- ✅ Docker Compose orchestration
- ✅ Automated backup/restore scripts
- ✅ Health checks and monitoring
- ✅ Custom themes and providers support
- ✅ Pre-configured demo realm with users

## 🔧 Quick Commands

```bash
# Start all services
docker compose up -d

# View logs
docker compose logs -f keycloak-dev

# Stop services
docker compose down

# Backup database and realms
./backup.sh

# Restore from backup
./restore.sh <timestamp>

# Health check
curl http://localhost:9000/health
```

## 🧪 Demo Realm

**Realm:** `demo-app`

### Test Users

| Username | Password | Roles | Use Case |
|----------|----------|-------|----------|
| `demo-user` | `Demo@User123` | `user` | Standard user access testing |
| `admin-user` | `Admin@User123` | `admin`, `user` | Full admin privileges testing |

### Pre-configured Clients

| Client ID | Type | Access Type | Redirect URIs | Purpose |
|-----------|------|-------------|---------------|---------|
| `demo-app-frontend` | Public | Browser-based | `http://localhost:3000/*` | SPA applications (React, Vue, Angular) |
| `demo-app-backend` | Confidential | Server-side | `http://localhost:8000/*` | Backend APIs with client secret |

### Quick Test

```bash
# Test login with demo-user
curl -X POST "http://localhost:8080/realms/demo-app/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=demo-user" \
  -d "password=Demo@User123" \
  -d "grant_type=password" \
  -d "client_id=demo-app-frontend"

# Or use the FastAPI integration
curl http://localhost:8000/login
```

### Realm Features

- 🔒 Password policy enabled (12+ chars, mixed case, numbers, special chars)
- 🛡️ Brute force protection configured
- 📧 Email verification workflow (via Mailhog)
- 🔑 Token lifetime: 5 minutes (access), 30 minutes (refresh)

## 🌐 Service URLs

| Service | URL | Purpose |
|---------|-----|---------|
| Keycloak Admin | http://localhost:8080/admin | Administration console |
| Keycloak Health | http://localhost:9000/health | Health check endpoint |
| Keycloak Metrics | http://localhost:9000/metrics | Prometheus metrics |
| FastAPI App | http://localhost:8000 | Demo integration app |
| FastAPI Docs | http://localhost:8000/docs | Interactive API documentation |
| Mailhog UI | http://localhost:8025 | Email testing interface |
| Adminer | http://localhost:8081 | PostgreSQL web interface |

## 📖 Integration Examples

### Frontend (React/Vue/Angular)

**Installation:**
```bash
npm install keycloak-js
```

**Usage:**
```javascript
import Keycloak from 'keycloak-js';

const keycloak = new Keycloak({
  url: 'http://localhost:8080',
  realm: 'demo-app',
  clientId: 'demo-app-frontend'
});

// Initialize with PKCE for security
await keycloak.init({ 
  onLoad: 'login-required',
  pkceMethod: 'S256'
});

// Get user info
const userProfile = keycloak.tokenParsed;
console.log(`Welcome ${userProfile.preferred_username}`);
console.log(`Email: ${userProfile.email}`);

// Check roles
if (keycloak.hasRealmRole('admin')) {
  console.log('User has admin privileges');
}

// Protected API call with token
fetch('http://localhost:8000/protected', {
  headers: {
    'Authorization': `Bearer ${keycloak.token}`
  }
});

// Logout
keycloak.logout();
```

**Full example:** See [`keycloak/examples/react-integration.js`](keycloak/examples/react-integration.js)

---

### Backend (Python/FastAPI)

**Installation:**
```bash
pip install fastapi python-jose[cryptography] requests python-multipart
```

**Token Validation:**
```python
from jose import jwt, JWTError
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
import requests

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# Get JWKS from Keycloak (cache this in production)
KEYCLOAK_URL = "http://localhost:8080"
REALM = "demo-app"
jwks_url = f"{KEYCLOAK_URL}/realms/{REALM}/protocol/openid-connect/certs"
jwks = requests.get(jwks_url).json()

async def get_current_user(token: str = Depends(oauth2_scheme)):
    try:
        # Decode and validate JWT
        payload = jwt.decode(
            token, 
            jwks, 
            algorithms=["RS256"],
            audience="account"
        )
        username = payload.get("preferred_username")
        if username is None:
            raise HTTPException(status_code=401, detail="Invalid token")
        return payload
    except JWTError:
        raise HTTPException(status_code=401, detail="Could not validate credentials")

# Protected endpoint
@app.get("/protected")
async def protected_route(current_user = Depends(get_current_user)):
    return {
        "message": f"Hello {current_user['preferred_username']}",
        "email": current_user.get("email"),
        "roles": current_user.get("realm_access", {}).get("roles", [])
    }

# Role-based access control
@app.get("/admin")
async def admin_route(current_user = Depends(get_current_user)):
    roles = current_user.get("realm_access", {}).get("roles", [])
    if "admin" not in roles:
        raise HTTPException(status_code=403, detail="Admin access required")
    return {"message": "Admin area"}
```

**Full working application:** [`fast-api-app/main.py`](fast-api-app/main.py)

**Test the integration:**
```bash
cd fast-api-app
./test.sh  # Runs automated tests against Keycloak
```

---

### Other Languages

**Java/Spring Boot:**
```xml
<!-- pom.xml -->
<dependency>
    <groupId>org.keycloak</groupId>
    <artifactId>keycloak-spring-boot-starter</artifactId>
</dependency>
```
See example: [`keycloak/examples/spring-boot-integration.py`](keycloak/examples/spring-boot-integration.py)

**Python (Flask/Django):**
```bash
pip install python-keycloak
```
See example: [`keycloak/examples/python-fastapi-integration.py`](keycloak/examples/python-fastapi-integration.py)

Full integration examples available in `/keycloak/examples/` directory.

## 🏗️ Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                      Client Applications                          │
│   (React/Vue/Angular)    (Mobile Apps)    (Backend Services)     │
└───────────┬──────────────────────┬──────────────────┬────────────┘
            │                      │                  │
            │   OAuth2/OIDC/SAML   │                  │
            ▼                      ▼                  ▼
   ┌────────────────────────────────────────────────────────────┐
   │                  Keycloak (Port 8080)                      │
   │  ┌──────────────────────────────────────────────────────┐ │
   │  │  Realms  │  Clients  │  Users  │  Roles  │  Sessions│ │
   │  └──────────────────────────────────────────────────────┘ │
   │                     Identity Provider                      │
   └────────────┬───────────────────────┬───────────────────────┘
                │                       │
                ▼                       ▼
   ┌──────────────────────┐  ┌──────────────────────────┐
   │  PostgreSQL (5432)   │  │   Mailhog (1025/8025)    │
   │  ┌────────────────┐  │  │  ┌────────────────────┐  │
   │  │ - User data    │  │  │  │ - Email testing   │  │
   │  │ - Sessions     │  │  │  │ - SMTP server     │  │
   │  │ - Realms       │  │  │  │ - Preview emails  │  │
   │  │ - Audit logs   │  │  │  └────────────────────┘  │
   │  └────────────────┘  │  └──────────────────────────┘
   └──────────────────────┘
            │
            ▼
   ┌──────────────────────┐
   │  Adminer (8081)      │
   │  - DB Management     │
   │  - Query Interface   │
   └──────────────────────┘
```

### Data Flow

1. **User Authentication**: Client → Keycloak login page → User credentials → Keycloak validates
2. **Token Generation**: Keycloak → JWT tokens (access + refresh) → Client
3. **API Access**: Client → Backend API (with token) → Validates token → Returns data
4. **Token Refresh**: Client → Keycloak (refresh token) → New access token

## 🏗️ Project Structure

```
keycloak/
├── keycloak/                      # Keycloak Docker environment
│   ├── docker-compose.yml         # Main services configuration
│   ├── docker-compose.monitoring.yml  # Monitoring stack
│   ├── realms/                    # Realm configurations
│   ├── examples/                  # Integration code samples
│   ├── themes/                    # Custom themes
│   ├── providers/                 # Custom providers (JAR files)
│   └── *.sh                       # Automation scripts
│
└── fast-api-app/                  # FastAPI integration example
    ├── main.py                    # Complete FastAPI app with OAuth2
    ├── Dockerfile                 # Container image
    ├── requirements.txt           # Python dependencies
    └── *.sh                       # Helper scripts
```

## 🔐 Security Notes

### Development Mode
- HTTP enabled (not HTTPS)
- Default admin credentials
- CORS open for localhost
- ⚠️ **NOT for production use**

### Production Recommendations
- Use HTTPS with valid certificates
- Change all default passwords
- Configure proper hostnames
- Enable strict security policies
- Set up backup automation
- Configure monitoring and alerts
- Use optimized Keycloak build (see `keycloak-custom/Dockerfile`)

## 🛠️ Customization

### Add Custom Theme
1. Create theme in `keycloak/themes/my-theme/`
2. Mount volume in docker-compose.yml
3. Select theme in Realm Settings

### Add Custom Provider
1. Place JAR file in `keycloak/providers/`
2. Restart Keycloak: `docker compose restart keycloak-dev`

### Import Custom Realm
1. Add JSON file to `keycloak/realms/`
2. Restart with: `docker compose up -d`

## 📊 Monitoring

Enable monitoring stack:
```bash
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d
```

Access:
- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090

## 🆘 Troubleshooting

### Issue: Keycloak won't start

**Symptoms:** Container exits immediately or health check fails

**Solutions:**
```bash
# 1. Check logs for specific error
docker compose logs keycloak-dev

# 2. Verify PostgreSQL is healthy
docker compose ps postgres  # Should show "healthy" status

# 3. Test database connectivity
docker exec keycloak-dev ping postgres

# 4. Check if port 8080 is already in use
sudo lsof -i :8080
# If occupied, stop the process or change port in docker-compose.yml

# 5. Reset everything (⚠️ DELETES ALL DATA)
docker compose down -v
docker compose up -d
```

**Common causes:**
- PostgreSQL not fully initialized (wait 30 seconds)
- Port conflict with another service
- Corrupted database volume
- Insufficient memory (Keycloak needs ~2GB RAM)

---

### Issue: Can't login to Admin Console

**Symptoms:** "Invalid credentials" or "User not found"

**Solutions:**
```bash
# 1. Verify admin credentials
cat keycloak/.env | grep KC_BOOTSTRAP_ADMIN
# Default: admin / admin

# 2. Check if admin user was created
docker compose logs keycloak-dev | grep -i "added user"

# 3. Reset admin account (⚠️ recreates containers)
docker compose down -v
docker compose up -d
# Wait 1 minute for initialization
```

---

### Issue: FastAPI can't connect to Keycloak

**Symptoms:** `Connection refused` or `Name or service not known`

**Solutions:**
```bash
# 1. Check if Keycloak is running
docker compose ps keycloak-dev

# 2. Test network connectivity from FastAPI container
docker exec -it keycloak-fastapi-demo ping keycloak-dev
# Should respond successfully

# 3. Verify Keycloak is accessible
curl http://localhost:8080/health
curl http://localhost:8080/realms/demo-app/.well-known/openid-configuration

# 4. Check Docker network
docker network inspect keycloak_keycloak-network

# 5. Restart FastAPI container
docker compose restart keycloak-fastapi-demo
```

---

### Issue: Invalid or expired tokens

**Symptoms:** `Invalid signature`, `Token expired`, or `401 Unauthorized`

**Solutions:**
```bash
# 1. Check token issuer matches realm
# Token should have: "iss": "http://localhost:8080/realms/demo-app"
# Decode token at https://jwt.io

# 2. Verify system time is synchronized
date
# Ensure your system time is correct (token validation is time-sensitive)

# 3. Get fresh token
curl -X POST "http://localhost:8080/realms/demo-app/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=demo-user" \
  -d "password=Demo@User123" \
  -d "grant_type=password" \
  -d "client_id=demo-app-frontend"

# 4. Verify JWKS endpoint is accessible
curl http://localhost:8080/realms/demo-app/protocol/openid-connect/certs

# 5. Check token lifetime settings in Keycloak Admin Console
# Realm Settings → Tokens → Access Token Lifespan
```

---

### Issue: CORS errors in browser

**Symptoms:** `Access-Control-Allow-Origin` errors in browser console

**Solutions:**
1. Go to Keycloak Admin Console
2. Navigate to: Clients → `demo-app-frontend`
3. Scroll to **Web Origins**
4. Add your frontend URL (e.g., `http://localhost:3000`)
5. Click **Save**

```bash
# Or using curl:
curl -X PUT "http://localhost:8080/admin/realms/demo-app/clients/{client-id}" \
  -H "Content-Type: application/json" \
  -d '{"webOrigins": ["http://localhost:3000", "http://localhost:8000"]}'
```

---

### Issue: Email verification not working

**Symptoms:** Verification emails not received

**Solutions:**
```bash
# 1. Check Mailhog UI
open http://localhost:8025
# All emails should appear here

# 2. Verify SMTP settings in Keycloak
# Admin Console → Realm Settings → Email
# Server: mailhog
# Port: 1025
# From: noreply@keycloak.local

# 3. Test email sending
# Admin Console → Users → Select user → Send verification email

# 4. Check Mailhog logs
docker compose logs mailhog
```

---

### Issue: Port conflicts

**Symptoms:** `address already in use` error

**Solutions:**
```bash
# Find which process is using the port
sudo lsof -i :8080  # Keycloak
sudo lsof -i :5432  # PostgreSQL
sudo lsof -i :8025  # Mailhog

# Option 1: Stop the conflicting process
sudo kill -9 <PID>

# Option 2: Change port in docker-compose.yml
# Edit ports section:
ports:
  - "8081:8080"  # Map to different host port
```

---

### Still having issues?

📚 **Check detailed guides:**
- [Keycloak Setup & Components Guide](keycloak/README.md#troubleshooting)
- [FastAPI Integration Guide](fast-api-app/README.md#troubleshooting)
- [Keycloak Server Administration](https://www.keycloak.org/docs/latest/server_admin/)

💬 **Get help:**
- [Keycloak Discourse](https://keycloak.discourse.group/)
- [Stack Overflow - Keycloak Tag](https://stackoverflow.com/questions/tagged/keycloak)
- Open an issue in this repository

## 📝 License

MIT License - Feel free to use this setup as a foundation for your projects.

## 🤝 Contributing

Found a bug or have suggestions? Feel free to open an issue or submit a pull request.

## 🔗 Resources

- [Keycloak Official Documentation](https://www.keycloak.org/documentation)
- [OAuth 2.0 Specification](https://oauth.net/2/)
- [OpenID Connect](https://openid.net/connect/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)

---

## 🎯 Next Steps

After getting the basic setup running, explore these areas:

### 1. Explore the Admin Console
- [ ] Browse the `demo-app` realm configuration
- [ ] Create a custom realm for your project
- [ ] Add additional test users
- [ ] Configure social login providers (Google, GitHub, etc.)
- [ ] Customize email templates

### 2. Try the Integration Examples
- [ ] Run FastAPI demo: `cd fast-api-app && ./test.sh`
- [ ] Test React/SPA integration: [`keycloak/examples/react-integration.js`](keycloak/examples/react-integration.js)
- [ ] Explore Spring Boot example: [`keycloak/examples/spring-boot-integration.py`](keycloak/examples/spring-boot-integration.py)
- [ ] Test token validation and refresh workflows

### 3. Customize for Your Project
- [ ] Import your own realm configuration (JSON export/import)
- [ ] Create custom themes (login, account, email)
- [ ] Add custom authentication providers (SPIs)
- [ ] Configure LDAP/Active Directory integration
- [ ] Set up User Federation for existing user bases

### 4. Enable Monitoring
- [ ] Start monitoring stack: `docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d`
- [ ] Explore Grafana dashboards → http://localhost:3000
- [ ] Configure Prometheus alerts
- [ ] Set up log aggregation (optional: ELK stack)

### 5. Production Readiness
- [ ] Enable HTTPS with valid SSL/TLS certificates
- [ ] Configure proper public hostnames
- [ ] Change all default passwords and secrets
- [ ] Set up automated database backups
- [ ] Configure email provider (SendGrid, AWS SES, etc.)
- [ ] Enable clustering for high availability
- [ ] Review security checklist: [`keycloak/README.md`](keycloak/README.md#production-deployment)
- [ ] Set up CI/CD pipeline for realm configuration

### 6. Learn More
- [ ] Complete [Keycloak Getting Started Guide](https://www.keycloak.org/getting-started)
- [ ] Watch [Keycloak video tutorials](https://www.youtube.com/results?search_query=keycloak+tutorial)
- [ ] Read [OAuth 2.0 Simplified](https://oauth.net/2/)
- [ ] Join [Keycloak Community](https://keycloak.discourse.group/)

---

## 📚 Learning Resources

### Official Documentation
- **Keycloak Docs**: [https://www.keycloak.org/documentation](https://www.keycloak.org/documentation)
- **Server Admin Guide**: [https://www.keycloak.org/docs/latest/server_admin/](https://www.keycloak.org/docs/latest/server_admin/)
- **Securing Applications**: [https://www.keycloak.org/docs/latest/securing_apps/](https://www.keycloak.org/docs/latest/securing_apps/)

### Protocols & Standards
- **OAuth 2.0**: [https://oauth.net/2/](https://oauth.net/2/)
- **OpenID Connect**: [https://openid.net/connect/](https://openid.net/connect/)
- **SAML 2.0**: [https://en.wikipedia.org/wiki/SAML_2.0](https://en.wikipedia.org/wiki/SAML_2.0)
- **JWT**: [https://jwt.io/introduction](https://jwt.io/introduction)

### Video Tutorials
- [Keycloak - Getting Started](https://www.youtube.com/results?search_query=keycloak+getting+started)
- [OAuth 2.0 Explained](https://www.youtube.com/results?search_query=oauth+2.0+explained)

### Community
- **Keycloak Discourse**: [https://keycloak.discourse.group/](https://keycloak.discourse.group/)
- **Stack Overflow**: [keycloak tag](https://stackoverflow.com/questions/tagged/keycloak)
- **GitHub Discussions**: [Keycloak GitHub](https://github.com/keycloak/keycloak/discussions)

---

**Made with ❤️ for DevOps and Developers**
