# Valid SSL Certificates for Production

This guide explains how to generate and install valid SSL certificates for your Keycloak production environment.

## 🔐 Certificate Generation Options

### Option 1: Let's Encrypt (Recommended) ✅

**Best for:**
- Public-facing production servers
- Automatic renewal needed
- Free certificates

**Prerequisites:**
- Domain name pointing to your server
- Port 80 accessible from internet
- Docker installed (uses official Certbot image)

**Generate:**
```bash
# Simple one-command generation
./scripts/prod/generate-valid-certs.sh keycloak.example.com admin@example.com

# Or use the short alias
./scripts/prod/letsencrypt.sh keycloak.example.com admin@example.com
```

**What it does:**
- Uses official `certbot/certbot` Docker image
- Generates valid SSL certificates
- Copies directly to `nginx/certs/`
- No persistent directories needed
- Auto-cleans temporary files

**Auto-renewal:**
```bash
# Renew certificates (detects domain automatically)
./scripts/prod/generate-valid-certs.sh --renew

# Setup cron for automatic renewal (runs twice daily)
crontab -e

# Add this line:
0 0,12 * * * cd /path/to/keycloak-lab && ./scripts/prod/generate-valid-certs.sh --renew >> /var/log/certbot.log 2>&1
```

---

### Option 2: Self-Signed Certificates (Testing Only)

**Best for:**
- Local development
- Internal testing
- Non-production environments

**Generate:**
```bash
./scripts/dev/generate-certs.sh
```

⚠️ **WARNING:** Browsers will show security warnings. Not valid for production!

---

### Option 3: Commercial Certificate Authority

**Best for:**
- Enterprise environments
- Extended validation (EV) certificates
- Wildcard certificates
- Warranty coverage

**Popular CAs:**
- [DigiCert](https://www.digicert.com) - Industry leader, EV certificates
- [GlobalSign](https://www.globalsign.com) - Global presence
- [Sectigo](https://sectigo.com) - Affordable options
- [GoDaddy](https://www.godaddy.com) - User-friendly

**Manual CSR generation:**
```bash
# Generate private key and CSR
openssl req -new -newkey rsa:2048 -nodes \
  -keyout nginx/certs/server.key \
  -out nginx/certs/server.csr \
  -subj "/C=US/ST=State/L=City/O=YourCompany/CN=your-domain.com"

# Display CSR (submit to CA)
cat nginx/certs/server.csr
```

**After receiving certificate from CA:**
Copy certificate files to `nginx/certs/server.crt` and `nginx/certs/server.key`

---

### Option 4: Cloud Provider Certificates

**Best for:**
- Cloud deployments
- Integration with cloud load balancers
- Managed certificate lifecycle

#### AWS Certificate Manager (ACM)

```bash
# Request certificate
aws acm request-certificate \
  --domain-name your-domain.com \
  --validation-method DNS

# Export certificate (for direct use)
aws acm export-certificate \
  --certificate-arn arn:aws:acm:region:account:certificate/id \
  --passphrase $(openssl rand -base64 32)
```

**Recommended:** Use ACM with Application Load Balancer (ALB) for SSL termination

#### Azure Key Vault

```bash
# Create certificate
az keyvault certificate create \
  --vault-name your-vault \
  --name keycloak-cert \
  --policy @policy.json

# Download certificate
az keyvault certificate download \
  --vault-name your-vault \
  --name keycloak-cert \
  --file nginx/certs/server.crt
```

**Recommended:** Use Azure Application Gateway for SSL termination

#### Google Cloud Certificate Manager

```bash
# Create managed certificate
gcloud compute ssl-certificates create keycloak-cert \
  --domains=your-domain.com

# Or create self-managed
gcloud compute ssl-certificates create keycloak-cert \
  --certificate=nginx/certs/server.crt \
  --private-key=nginx/certs/server.key
```

**Recommended:** Use Cloud Load Balancer for SSL termination

---

## 📋 Installation Methods

### Automated Script (Recommended) ⭐

```bash
# Generate new certificate
./scripts/prod/generate-valid-certs.sh your-domain.com your-email@example.com

# Renew existing certificate
./scripts/prod/generate-valid-certs.sh --renew
```

**Features:**
- ✅ One command generation
- ✅ Uses official Certbot Docker image
- ✅ No installation required (Docker only)
- ✅ Auto-cleanup of temporary files
- ✅ Built-in renewal function

---

### Manual Installation

If you already have certificate files:

```bash
# Copy your certificate and key
cp /path/to/your/certificate.crt nginx/certs/server.crt
cp /path/to/your/private.key nginx/certs/server.key

# Set permissions
chmod 644 nginx/certs/server.crt
chmod 600 nginx/certs/server.key

# If you have intermediate/chain certificates
cat certificate.crt intermediate.crt > nginx/certs/server.crt
```

---

## 🔍 Certificate Verification

### Check Certificate Details

```bash
# View certificate information
openssl x509 -in nginx/certs/server.crt -noout -text

# Check expiration date
openssl x509 -in nginx/certs/server.crt -noout -dates

# Verify certificate chain
openssl verify -CAfile ca-bundle.crt nginx/certs/server.crt

# Test certificate with private key
openssl x509 -noout -modulus -in nginx/certs/server.crt | openssl md5
openssl rsa -noout -modulus -in nginx/certs/server.key | openssl md5
# Both MD5 hashes should match
```

### Test SSL Configuration

```bash
# Start production environment
./scripts/prod/start.sh

# Test HTTPS connection
curl -v https://your-domain.com:8443/health

# Test with SSL Labs (after deployment)
# Visit: https://www.ssllabs.com/ssltest/
```

---

## 🔄 Certificate Renewal

### Let's Encrypt (Auto-renewal)

**Using the built-in renewal function:**
```bash
# Renew certificates (detects domain from existing certificate)
./scripts/prod/generate-valid-certs.sh --renew

# Or use short alias
./scripts/prod/letsencrypt.sh --renew
```

**Setup auto-renewal with cron:**
```bash
# Edit crontab
crontab -e

# Add renewal job (runs twice daily at midnight and noon)
0 0,12 * * * cd /path/to/keycloak-lab && ./scripts/prod/generate-valid-certs.sh --renew >> /var/log/certbot.log 2>&1
```

**How it works:**
1. Automatically detects domain from existing certificate
2. Uses Certbot Docker to renew
3. Copies renewed certificates to `nginx/certs/`
4. Restarts Keycloak if running
5. Cleans up temporary files

### Commercial CA

Set calendar reminder for expiration (usually 1 year):
```bash
# Check expiration
openssl x509 -in nginx/certs/server.crt -noout -enddate

# Renew 30 days before expiration
# Generate new CSR and repeat purchase process
```

---

## 🏗️ Production Architecture Options

### Option A: Direct SSL Termination (Simple)

```
Internet → Keycloak (HTTPS 8443) → PostgreSQL
```

**Use when:**
- Single server deployment
- Simple architecture
- Direct access needed

**Certificate location:** `nginx/certs/`

---

### Option B: Reverse Proxy SSL Termination (Recommended)

```
Internet → Nginx/HAProxy (HTTPS 443) → Keycloak (HTTP 8080) → PostgreSQL
```

**Use when:**
- Multiple services behind proxy
- Need load balancing
- Advanced routing required

**Certificate location:** Nginx/proxy configuration

---

### Option C: Cloud Load Balancer SSL Termination (Cloud-Native)

```
Internet → ALB/AppGW/CloudLB (HTTPS 443) → Keycloak (HTTP 8080) → PostgreSQL
```

**Use when:**
- Deployed on cloud (AWS/Azure/GCP)
- High availability required
- Managed certificates preferred

**Certificate location:** Cloud provider certificate manager

---

## 🔒 Security Best Practices

### Certificate Management

- ✅ Use strong private keys (RSA 2048+ or ECC 256+)
- ✅ Protect private keys (chmod 600)
- ✅ Use certificate chains (include intermediates)
- ✅ Enable OCSP stapling
- ✅ Monitor expiration dates
- ✅ Automate renewal process
- ❌ Never commit private keys to git
- ❌ Don't use same certificate across environments

### SSL/TLS Configuration

```yaml
# Recommended settings in docker-compose.prod.yml
environment:
  KC_HTTPS_PROTOCOLS: TLSv1.3,TLSv1.2
  KC_HTTPS_CIPHER_SUITES: >
    TLS_AES_256_GCM_SHA384,
    TLS_AES_128_GCM_SHA256,
    TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
```

---

## 🆘 Troubleshooting

### Certificate Errors

**"Certificate not valid"**
```bash
# Check certificate dates
openssl x509 -in nginx/certs/server.crt -noout -dates

# Verify domain matches
openssl x509 -in nginx/certs/server.crt -noout -text | grep DNS
```

**"Private key mismatch"**
```bash
# Verify key matches certificate
diff <(openssl x509 -noout -modulus -in server.crt | openssl md5) \
     <(openssl rsa -noout -modulus -in server.key | openssl md5)
```

**"Certificate chain incomplete"**
```bash
# Add intermediate certificates
cat server.crt intermediate.crt > fullchain.crt
```

### Let's Encrypt Issues

**Port 80 blocked:**
Port 80 must be accessible from the internet for HTTP challenge. If blocked, use DNS challenge manually or open the port temporarily.

**Rate limits exceeded:**
Let's Encrypt has rate limits (50 certificates per domain per week). For testing, wait or use a different subdomain.

**Certificate renewal fails:**
```bash
# Check if certificate needs renewal (< 30 days remaining)
openssl x509 -in nginx/certs/server.crt -noout -enddate

# Force renewal by regenerating
./scripts/prod/generate-valid-certs.sh your-domain.com your-email@example.com
```

---

## 📚 Additional Resources

### Documentation
- [Let's Encrypt](https://letsencrypt.org/docs/)
- [Certbot](https://certbot.eff.org/)
- [SSL Labs](https://www.ssllabs.com/ssltest/)
- [Mozilla SSL Config Generator](https://ssl-config.mozilla.org/)

### Tools
- [SSL Checker](https://www.sslshopper.com/ssl-checker.html)
- [Certificate Decoder](https://www.sslshopper.com/certificate-decoder.html)
- [CSR Decoder](https://www.sslshopper.com/csr-decoder.html)

---

## 🚀 Quick Start

**For testing/development:**
```bash
./scripts/prod/generate-certs.sh  # Self-signed certificates
```

**For production (Let's Encrypt):**
```bash
# Generate certificate
./scripts/prod/generate-valid-certs.sh keycloak.example.com admin@example.com

# Or use short alias
./scripts/prod/letsencrypt.sh keycloak.example.com admin@example.com
```

**Renew certificate:**
```bash
./scripts/prod/generate-valid-certs.sh --renew
```

**Start production:**
```bash
./scripts/prod/start.sh
```

**Verify:**
```bash
curl -k https://localhost:8443/health
./scripts/prod/test.sh
```

---

## 📁 File Structure

After certificate generation:
```
keycloak-lab/
└── nginx/certs/          # Only directory needed
    ├── server.crt       # SSL certificate (fullchain)
    └── server.key       # Private key
```

**No additional files:**
- ❌ No `letsencrypt/` directory
- ❌ No separate renewal scripts
- ❌ No persistent Certbot data
- ✅ Clean and simple!

**Verify:**
```bash
curl -k https://localhost:8443/health
./scripts/prod/test.sh
```
