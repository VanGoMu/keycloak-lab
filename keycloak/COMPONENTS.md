# Keycloak Integration Components

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
