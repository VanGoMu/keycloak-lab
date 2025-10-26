# Keycloak Identity & Access Management - Docker Environment

Complete Keycloak setup with Docker Compose, featuring both development and production modes, pre-configured realms, and FastAPI integration example.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Keycloak](https://img.shields.io/badge/Keycloak-26.0.7-blue)](https://www.keycloak.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-blue)](https://www.postgresql.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115.6-green)](https://fastapi.tiangolo.com/)

---

## 🚀 Quick Start

### Development Mode (HTTP)

```bash
# 1. Clone the repository
git clone <repository-url>
cd keycloak-lab

# 2. Start development mode
./start.sh
# Select option 1

# 3. Verify it's running
curl http://localhost:9000/health
# Expected: {"status":"UP"}

# 4. Access admin console
# URL: http://localhost:8080/admin
# Credentials: admin / admin
```

### Production Mode (HTTPS)

```bash
# 1. Start production mode
./start.sh
# Select option 2

# 2. Access admin console (accept self-signed certificate warning)
# URL: https://localhost:8443/admin
# Credentials: admin / admin

# 3. Test configuration
./scripts/prod/test.sh
```

**✅ Quick Verification:**
- [ ] Admin Console accessible
- [ ] Mailhog UI working → http://localhost:8025
- [ ] FastAPI responding → http://localhost:8000
- [ ] Health check OK → `curl http://localhost:9000/health`

---

## 📦 What's Included

### Core Services

| Service | Version | Purpose | Ports (Dev) | Ports (Prod) |
|---------|---------|---------|-------------|--------------|
| **Keycloak** | 26.0.7 | IAM Server | 8080, 9000 | 8443, 9000 |
| **PostgreSQL** | 16-alpine | Database | 5432 | 5432 |
| **Mailhog** | latest | SMTP Testing | 1025, 8025 | 1025, 8025 |
| **Adminer** | latest | DB UI | 8081 | 8081 |
| **FastAPI** | Custom | Example App | 8000 | 8000 |

### Features Out-of-the-Box
- ✅ Pre-configured `demo-app` realm with test users
- ✅ OAuth2/OIDC clients ready to use
- ✅ SMTP configured (Mailhog for email testing)
- ✅ Health checks and Prometheus metrics
- ✅ Role-based access control (RBAC) examples
- ✅ Development and production modes

---

## 📚 Documentation

### Main Guides

| Document | Description |
|----------|-------------|
| [README.md](README.md) | This file - Quick start and overview |
| [keycloak/README.md](keycloak/README.md) | Complete Keycloak setup guide |
| [fast-api-app/README.md](fast-api-app/README.md) | FastAPI integration guide |
| [scripts/README.md](scripts/README.md) | Automation scripts documentation |

---

## 🎯 Key Features

### Security & Authentication
- ✅ Single Sign-On (SSO)
- ✅ OAuth 2.0 / OpenID Connect / SAML 2.0
- ✅ Multi-Factor Authentication (MFA)
- ✅ Social Login (Google, GitHub, etc.)
- ✅ User Federation (LDAP/Active Directory)
- ✅ Fine-grained Authorization

### Development & Operations
- ✅ Docker Compose orchestration
- ✅ Automated setup scripts
- ✅ Health checks and monitoring
- ✅ Custom themes and providers support
- ✅ Pre-configured demo realm

---

## 🔧 Quick Commands

### Development Mode

```bash
# Start
./scripts/dev/start.sh

# View logs
cd docker && docker compose -f docker-compose.dev.yml logs -f keycloak-dev

# Stop
cd docker && docker compose -f docker-compose.dev.yml down

# Restart
cd docker && docker compose -f docker-compose.dev.yml restart keycloak-dev
```

### Production Mode

```bash
# Start
./scripts/prod/start.sh

# View logs
cd docker && docker compose -f docker-compose.prod.yml logs -f keycloak-prod

# Stop
cd docker && docker compose -f docker-compose.prod.yml down

# Test
./scripts/prod/test.sh

# Generate certificates
./scripts/prod/generate-certs.sh
```

---

## 🌐 Service URLs

### Development Mode

| Service | URL | Credentials |
|---------|-----|-------------|
| Admin Console | http://localhost:8080/admin | admin / admin |
| Health Check | http://localhost:9000/health | - |
| Metrics | http://localhost:9000/metrics | - |
| FastAPI | http://localhost:8000 | - |
| FastAPI Docs | http://localhost:8000/docs | - |
| Mailhog UI | http://localhost:8025 | - |
| Adminer | http://localhost:8081 | See docker/.env |

### Production Mode

| Service | URL | Credentials |
|---------|-----|-------------|
| Admin Console | https://localhost:8443/admin | admin / admin |
| Health Check | http://localhost:9000/health | - |
| Metrics | http://localhost:9000/metrics | - |
| FastAPI | http://localhost:8000 | - |

---

## 🧪 Demo Realm

**Realm:** `demo-app`

### Test Users

> **Note:** Passwords are configured in `docker/.env`. Default values shown below.

| Username | Password | Roles | Use Case |
|----------|----------|-------|----------|
| `demo-user` | Ver `DEMO_USER_PASSWORD` en `docker/.env` | `user` | Standard user access |
| `admin-user` | Ver `ADMIN_USER_PASSWORD` en `docker/.env` | `admin`, `user` | Admin privileges |

### Pre-configured Clients

| Client ID | Type | Redirect URIs | Purpose |
|-----------|------|---------------|---------|
| `demo-app-frontend` | Public | `http://localhost:3000/*` | SPA applications |

### Quick Test

```bash
# Load credentials from environment
source docker/.env

# Get token for demo-user
curl -X POST http://localhost:8000/login \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"demo-user\", \"password\": \"${DEMO_USER_PASSWORD}\"}"
```

---

## 📖 Integration Examples

### Frontend (React/Vue/Angular)

**Installation:**
```bash
npm install keycloak-js
```

**Basic Usage:**
```javascript
import Keycloak from 'keycloak-js';

const keycloak = new Keycloak({
  url: 'http://localhost:8080',
  realm: 'demo-app',
  clientId: 'demo-app-frontend'
});

// Initialize
await keycloak.init({ 
  onLoad: 'login-required',
  pkceMethod: 'S256'
});

// Get user info
const user = keycloak.tokenParsed;
console.log(`Welcome ${user.name}`);

// Check roles
if (keycloak.hasRealmRole('admin')) {
  console.log('User is admin');
}

// Logout
keycloak.logout();
```

**Full example:** [`keycloak/examples/react-integration.js`](keycloak/examples/react-integration.js)

---

### Backend (Python/FastAPI)

**Installation:**
```bash
pip install fastapi python-jose[cryptography] requests
```

**Token Validation:**
```python
from jose import jwt
from fastapi import Depends, HTTPException

async def get_current_user(token: str = Depends(oauth2_scheme)):
    try:
        jwks_url = f"{KEYCLOAK_URL}/realms/{REALM}/protocol/openid-connect/certs"
        jwks = requests.get(jwks_url).json()
        payload = jwt.decode(token, jwks, algorithms=["RS256"])
        return payload
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

@app.get("/protected")
async def protected(user = Depends(get_current_user)):
    return {"message": f"Hello {user['preferred_username']}"}
```

**Full working app:** [`fast-api-app/main.py`](fast-api-app/main.py)

**Test the integration:**
```bash
cd fast-api-app
./test.sh
```

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      Client Applications                     │
│  (React/Vue/Angular)    (Mobile Apps)    (Backend Services) │
└────────────┬────────────────────┬────────────────┬──────────┘
             │                    │                │
             │   OAuth2/OIDC      │                │
             ▼                    ▼                ▼
    ┌────────────────────────────────────────────────────┐
    │              Keycloak (Port 8080/8443)             │
    │  ┌──────────────────────────────────────────────┐ │
    │  │  Realms  │  Clients  │  Users  │  Roles     │ │
    │  └──────────────────────────────────────────────┘ │
    └────────────┬──────────────────────┬────────────────┘
                 │                      │
                 ▼                      ▼
    ┌─────────────────────┐  ┌──────────────────────┐
    │ PostgreSQL (5432)   │  │  Mailhog (1025/8025) │
    │  - User data        │  │  - Email testing     │
    │  - Sessions         │  │  - SMTP server       │
    │  - Realms           │  │                      │
    └─────────────────────┘  └──────────────────────┘
```

---

## 🔐 Security Notes

### Development Mode
- HTTP enabled (not HTTPS)
- Default admin credentials
- CORS open for localhost
- ⚠️ **NOT for production use**

### Production Recommendations
- Use HTTPS with valid certificates
- Change all default passwords in `docker/.env`
- Configure proper hostnames
- Enable strict security policies
- Set up backup automation
- Configure monitoring and alerts

---

## 🆘 Troubleshooting

### Issue: Keycloak won't start

**Symptoms:** Container exits or health check fails

**Solutions:**
```bash
# Check logs
cd docker && docker compose -f docker-compose.dev.yml logs keycloak-dev

# Verify PostgreSQL is healthy
cd docker && docker compose -f docker-compose.dev.yml ps postgres

# Reset (⚠️ DELETES DATA)
cd docker
docker compose -f docker-compose.dev.yml down -v
docker compose -f docker-compose.dev.yml up -d
```

### Issue: Can't login to Admin Console

**Solutions:**
```bash
# Verify credentials in .env
cat docker/.env | grep KC_ADMIN

# Reset containers
cd docker
docker compose -f docker-compose.dev.yml down -v
docker compose -f docker-compose.dev.yml up -d
```

### Issue: Port conflicts

**Solutions:**
```bash
# Find process using port
sudo lsof -i :8080

# Kill process or change port in docker/docker-compose.*.yml
```

### Still having issues?

- [Keycloak Setup Guide](keycloak/README.md#troubleshooting)
- [FastAPI Integration Guide](fast-api-app/README.md#troubleshooting)
- [Scripts Documentation](scripts/README.md#troubleshooting)

---

## 🎯 Next Steps

1. **Explore Admin Console**
   - Create custom realms
   - Add users and roles
   - Configure social login

2. **Try Integration Examples**
   - Run FastAPI demo: `cd fast-api-app && ./test.sh`
   - Test React integration
   - Explore examples in `keycloak/examples/`

3. **Customize**
   - Add custom themes
   - Create custom providers
   - Configure LDAP integration

4. **Production Ready**
   - Generate valid SSL certificates
   - Change default passwords in `docker/.env`
   - Set up monitoring
   - Configure backups

---

## 📝 License

MIT License - Feel free to use this setup for your projects.

---

## 🔗 Resources

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [OAuth 2.0 Specification](https://oauth.net/2/)
- [OpenID Connect](https://openid.net/connect/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)