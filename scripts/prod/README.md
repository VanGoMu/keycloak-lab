# Production Scripts

Scripts for managing Keycloak in production mode with HTTPS and SSL certificates.

## 📜 Available Scripts

### `start.sh` - Start Production Environment
Starts Keycloak in optimized production mode with HTTPS.

```bash
./scripts/prod/start.sh
```

**Features:**
- ✅ Auto-generates self-signed certificates if missing
- ✅ Creates necessary directories
- ✅ Validates Docker and OpenSSL
- ✅ Builds optimized Keycloak image
- ✅ Starts all production services

---

### `generate-certs.sh` - Generate Self-Signed Certificates
Creates self-signed SSL certificates for testing.

```bash
./scripts/prod/generate-certs.sh
```

**Use for:**
- Local testing
- Development environments
- Internal networks

**⚠️ NOT for production** - Browsers will show security warnings

---

### `generate-valid-certs.sh` - Generate Valid SSL Certificates ⭐
Interactive script for generating production-ready SSL certificates.

```bash
./scripts/prod/generate-valid-certs.sh
```

**Options:**

1. **Let's Encrypt (Recommended)** 🐳
   - Uses official `certbot/certbot` Docker image
   - No local installation required
   - Free, automated, trusted certificates
   - Auto-generates renewal script

2. **Manual Installation**
   - Use existing certificates from any CA
   - Supports PEM format files

3. **Self-Signed**
   - Quick generation for testing
   - Same as `generate-certs.sh`

4. **Commercial CA**
   - Generates CSR for DigiCert, GlobalSign, etc.
   - Enterprise certificates

5. **Cloud Providers**
   - Instructions for AWS, Azure, GCP
   - Managed certificates

**Why Docker-based Certbot?**
- ✅ No system dependencies
- ✅ Consistent across environments
- ✅ Official EFF-maintained image
- ✅ Isolated from host system
- ✅ Easy updates (`docker pull certbot/certbot`)
- ✅ Works on any OS with Docker

---

### `renew-certs.sh` - Renew Let's Encrypt Certificates
Auto-generated script for certificate renewal (created by `generate-valid-certs.sh`).

```bash
./scripts/prod/renew-certs.sh
```

**Features:**
- Renews certificates using Certbot Docker
- Copies renewed certificates to `nginx/certs/`
- Restarts Keycloak if running
- Can be automated with cron

**Setup auto-renewal:**
```bash
crontab -e

# Add this line (runs twice daily):
0 0,12 * * * cd /path/to/keycloak-lab && ./scripts/prod/renew-certs.sh >> /var/log/certbot-renew.log 2>&1
```

---

### `test.sh` - Test Production Configuration
Validates production setup and SSL configuration.

```bash
./scripts/prod/test.sh
```

**Tests:**
- HTTPS health endpoint
- HTTP disabled (security)
- SSL certificate validity
- Database connectivity
- Service availability

---

### `backup.sh` - Backup Production Data
Creates backups of Keycloak database and configuration.

```bash
./scripts/prod/backup.sh
```

**Backs up:**
- PostgreSQL database
- Keycloak realms
- Certificates
- Configuration files

---

### `restore.sh` - Restore from Backup
Restores Keycloak from a previous backup.

```bash
./scripts/prod/restore.sh
```

---

## 🚀 Quick Start

### First Time Setup

```bash
# 1. Generate valid certificates (Let's Encrypt)
./scripts/prod/generate-valid-certs.sh
# Select option 1, enter domain and email

# 2. Start production environment
./scripts/prod/start.sh

# 3. Verify everything is working
./scripts/prod/test.sh

# 4. Setup auto-renewal
crontab -e
# Add: 0 0,12 * * * cd /path/to/keycloak-lab && ./scripts/prod/renew-certs.sh >> /var/log/certbot-renew.log 2>&1
```

---

## 📋 Certificate Management

### Certificate Storage

```
keycloak-lab/
├── nginx/certs/              # Active certificates
│   ├── server.crt           # Certificate (fullchain)
│   └── server.key           # Private key
└── letsencrypt/             # Let's Encrypt storage
    ├── etc/                 # Certificate archives
    ├── var/lib/            # Account data
    └── var/log/            # Certbot logs
```

### Certificate Lifecycle

1. **Generation** → `generate-valid-certs.sh`
2. **Deployment** → Copies to `nginx/certs/`
3. **Renewal** → `renew-certs.sh` (auto-generated)
4. **Monitoring** → Check expiration dates

```bash
# Check certificate expiration
openssl x509 -in nginx/certs/server.crt -noout -dates

# Check certificate details
openssl x509 -in nginx/certs/server.crt -noout -text
```

---

## 🐳 Docker Images Used

### Certbot (Let's Encrypt)
- **Image:** `certbot/certbot`
- **Source:** [Docker Hub Official](https://hub.docker.com/r/certbot/certbot)
- **Maintained by:** Electronic Frontier Foundation (EFF)
- **Updates:** Regular security and feature updates
- **Trust:** Official Let's Encrypt client

**Why this image?**
- ✅ Official EFF project
- ✅ Verified publisher on Docker Hub
- ✅ 100M+ pulls
- ✅ Active development
- ✅ Security-focused organization

---

## 🔒 Security Best Practices

### Certificate Security
- ✅ Use Let's Encrypt for public domains
- ✅ Protect private keys (`chmod 600 server.key`)
- ✅ Never commit certificates to git
- ✅ Rotate certificates before expiration
- ✅ Monitor expiration dates
- ✅ Use strong cipher suites

### Production Checklist
- [ ] Valid SSL certificates installed
- [ ] Auto-renewal configured
- [ ] Default passwords changed
- [ ] Firewall configured (443, 8443 open)
- [ ] Database backups enabled
- [ ] Monitoring configured
- [ ] Logs centralized
- [ ] Resource limits set

---

## 🆘 Troubleshooting

### Certificate Generation Fails

**Port 80 in use:**
```bash
# Check what's using port 80
sudo lsof -i :80

# Stop the service or use DNS challenge
```

**DNS not configured:**
```bash
# Check DNS resolution
dig +short your-domain.com

# Should return your server's IP
```

**Docker not running:**
```bash
# Start Docker
sudo systemctl start docker

# Check status
docker ps
```

### Certificate Renewal Fails

```bash
# Test renewal manually
./scripts/prod/renew-certs.sh

# Check Certbot logs
cat letsencrypt/var/log/letsencrypt/letsencrypt.log

# Force renewal
docker run --rm \
  -p 80:80 \
  -v "$(pwd)/letsencrypt/etc:/etc/letsencrypt" \
  certbot/certbot renew --force-renewal
```

---

## 📚 Additional Documentation

- [SSL Certificates Guide](../../docs/SSL-CERTIFICATES.md) - Comprehensive certificate documentation
- [Keycloak Setup](../../keycloak/README.md) - Keycloak configuration guide
- [Main README](../../README.md) - Project overview

---

## 🔗 External Resources

- [Let's Encrypt](https://letsencrypt.org/)
- [Certbot Documentation](https://eff-certbot.readthedocs.io/)
- [Certbot Docker Hub](https://hub.docker.com/r/certbot/certbot)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
