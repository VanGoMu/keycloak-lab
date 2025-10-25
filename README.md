# Keycloak Identity & Access Management - Docker Environment

Complete Docker-based Keycloak setup with authentication examples and comprehensive documentation.

## 🚀 Quick Start

```bash
cd keycloak
./start.sh
```

Access Keycloak Admin Console: http://localhost:8080/admin  
**Credentials**: `admin` / `admin`

## 📦 What's Included

### Core Services
- **Keycloak 26.0.7** - Identity and Access Management server
- **PostgreSQL 16** - Persistent database
- **Mailhog** - SMTP testing server (http://localhost:8025)
- **Adminer** - Database management UI (http://localhost:8081)
- **FastAPI Demo App** - Python integration example (http://localhost:8000)

### Optional Monitoring Stack
- Prometheus + Grafana + PostgreSQL Exporter
- Enable with: `docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d`

## 📚 Documentation

### Main Documentation (Keycloak Setup)
Located in `/keycloak/` directory:

| Document | Description |
|----------|-------------|
| [README.md](keycloak/README.md) | Complete setup guide: installation, configuration, customization, production deployment |
| [QUICKSTART.md](keycloak/QUICKSTART.md) | Get started in 3 steps, common use cases, useful commands |
| [COMPONENTES.md](keycloak/COMPONENTES.md) | Related technologies: LDAP, social login, monitoring, cloud platforms |
| [ESTRUCTURA.md](keycloak/ESTRUCTURA.md) | Project structure explanation and file descriptions |
| [RESUMEN.md](keycloak/RESUMEN.md) | Project summary, features, and next steps |

### FastAPI Integration Example
Located in `/fast-api-app/` directory:

| Document | Description |
|----------|-------------|
| [README.md](fast-api-app/README.md) | FastAPI + Keycloak integration guide with OAuth2/OIDC |
| [INTERACCION-USUARIO.md](fast-api-app/INTERACCION-USUARIO.md) | Step-by-step user authentication flow and interaction patterns |

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

Pre-configured realm: `demo-app`

**Test Users:**
| Username | Password | Roles |
|----------|----------|-------|
| `demo-user` | `Demo@User123` | user |
| `admin-user` | `Admin@User123` | admin, user |

**Pre-configured Clients:**
- `demo-app-frontend` - Public client for SPAs (React, Vue, Angular)

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

### React/Vue/Angular (SPA)
```javascript
import Keycloak from 'keycloak-js';

const keycloak = new Keycloak({
  url: 'http://localhost:8080',
  realm: 'demo-app',
  clientId: 'demo-app-frontend'
});

await keycloak.init({ onLoad: 'login-required' });
```

### FastAPI (Backend)
```python
from fastapi import Depends, HTTPException
from jose import jwt

# See full example in fast-api-app/main.py
async def get_current_user(token: str = Depends(oauth2_scheme)):
    payload = jwt.decode(token, public_key, algorithms=["RS256"])
    return payload
```

Full integration examples available in `/keycloak/examples/` and `/fast-api-app/`

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

**Keycloak won't start:**
```bash
docker compose logs keycloak-dev
# Check PostgreSQL connectivity
docker exec keycloak-dev ping postgres
```

**Can't access admin console:**
- Verify port 8080 is not in use: `netstat -tuln | grep 8080`
- Check service status: `docker compose ps`

**Forgot admin password:**
```bash
docker compose down -v  # ⚠️ This deletes all data
docker compose up -d
```

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

**Made with ❤️ for DevOps and Developers**
