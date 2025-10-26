# Stress Testing Scripts

Automated scripts for load and stress testing of Keycloak and FastAPI using Docker containers.

## 📋 Requirements

### Docker

The only requirement is Docker (which you already have for running the services):

```bash
# Check Docker is installed
docker --version
```

All load testing tools run in Docker containers - **no local installation required**!

## 🚀 Quick Start

### Interactive Script (Recommended)

```bash
./scripts/stress-tests/run-stress-tests.sh
```

This will display an interactive menu:
1. Keycloak only
2. FastAPI only  
3. Both (sequential)
4. Exit

### Individual Scripts

#### Keycloak Test
```bash
./scripts/stress-tests/keycloak-stress-test.sh
```

#### FastAPI Test
```bash
./scripts/stress-tests/fastapi-stress-test.sh
```

## ⚙️ Configuration

### Environment Variables

All variables are optional. Default values are configured for the local environment:

```bash
# URLs (use host.docker.internal for Docker-to-host communication)
export KEYCLOAK_URL="https://host.docker.internal:8443"
export FASTAPI_URL="http://host.docker.internal:8000"

# Keycloak Credentials
export REALM="demo-app"
export CLIENT_ID="demo-app-frontend"
export USERNAME="demo-user"
export PASSWORD="Demo@User123"

# Load Configuration
export CONCURRENT_USERS="10"
export REQUESTS_PER_USER="100"

# Run test
./scripts/stress-tests/run-stress-tests.sh
```

### Configuration Examples

#### Light Test (development)
```bash
export CONCURRENT_USERS=5
export REQUESTS_PER_USER=50
./scripts/stress-tests/keycloak-stress-test.sh
```

#### Medium Test (staging)
```bash
export CONCURRENT_USERS=50
export REQUESTS_PER_USER=200
./scripts/stress-tests/run-stress-tests.sh
```

#### Heavy Test (production)
```bash
export CONCURRENT_USERS=100
export REQUESTS_PER_USER=1000
./scripts/stress-tests/run-stress-tests.sh
```

## � Docker Images Used

The scripts use official, trusted Docker images:

- **httpd:alpine** - Apache HTTP Server with Apache Bench (ab) tool
- **curlimages/curl:latest** - Official curl Docker image for API calls

Images are automatically pulled when needed.

## 📊 Tests Performed

### Keycloak

1. **Token Endpoint** - Access token generation
2. **JWKS Endpoint** - Public key discovery
3. **OpenID Configuration** - Provider configuration
4. **Health Endpoint** - Service status

### FastAPI

1. **Health Endpoint** - Service status
2. **Root Endpoint** - Public root endpoint
3. **Protected Endpoint** - JWT-protected endpoint
4. **User Info Endpoint** - Authenticated user information

## 📁 Results

Results are saved to:
Results are saved to:
```
stress-test-results/
├── keycloak-YYYYMMDD-HHMMSS/
│   ├── summary.txt
│   ├── token-endpoint.txt
│   ├── jwks-endpoint.txt
│   ├── openid-config.txt
│   └── health-endpoint.txt
├── fastapi-YYYYMMDD-HHMMSS/
│   ├── summary.txt
│   ├── health-endpoint.txt
│   ├── root-endpoint.txt
│   ├── protected-endpoint.txt
│   └── userinfo-endpoint.txt
└── complete-YYYYMMDD-HHMMSS/
    └── combined-report.txt
```

### View Results

```bash
# View latest summary
cat stress-test-results/*/summary.txt | tail -n 50

# List all results
ls -la stress-test-results/

# View combined report
cat stress-test-results/complete-*/combined-report.txt
```

## 📈 Results Analysis

### Key Metrics

The scripts report:
- **Requests per second** - Request processing rate
- **Time per request** - Average time per request
- **Failed requests** - Number of failed requests
- **Transfer rate** - Data transfer rate

### Grafana Dashboard

During and after tests, check the Grafana dashboard:

```
http://localhost:3000/d/keycloak-metrics
```

Important metrics:
- JVM Heap Usage
- CPU Usage
- HTTP Request Rate
- Database Connection Pool
- Thread Count

### Prometheus

Useful queries in Prometheus (`http://localhost:9090`):

```promql
# HTTP request rate
rate(http_server_requests_seconds_count[5m])

# Heap memory usage
jvm_memory_used_bytes{area="heap"}

# CPU usage
process_cpu_usage

# Active DB connections
agroal_active_count
```

## 🔧 Troubleshooting

### Error: "Docker is not installed"

Install Docker:
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install docker.io

# Or follow official guide
# https://docs.docker.com/get-docker/
```

### Error: "Failed to obtain access token"

Verify:
1. Keycloak is running: `docker ps | grep keycloak`
2. Correct credentials in environment variables
3. Realm and client exist: `https://localhost:8443/admin`
4. Using `host.docker.internal` for URL (not `localhost`)

### High "Failed requests" in Results

Common causes:
- System overloaded (reduce CONCURRENT_USERS)
- Timeouts (increase timeout in scripts)
- Insufficient resources (check memory and CPU)
- Network issues (check Docker network configuration)

### SSL Certificate Issues

For self-signed certificates (development):
- Scripts use `-k` flag to bypass certificate validation
- This is normal for local testing

For production with valid certificates:
```bash
export KEYCLOAK_URL="https://auth.yourdomain.com"
./scripts/stress-tests/keycloak-stress-test.sh
```

### Docker Network Issues

If tests fail to connect to services:

```bash
# Verify services are accessible
docker run --rm curlimages/curl:latest -k https://host.docker.internal:8443/health

# Check if services are running
docker ps

# On Linux, you may need to use actual IP instead of host.docker.internal
export KEYCLOAK_URL="https://$(hostname -I | awk '{print $1}'):8443"
```

## 💡 Best Practices

1. **Scale gradually**: Start with few users and increase incrementally
2. **Monitor resources**: Use Grafana during tests
3. **Test in staging**: Never use production for stress tests
4. **Warm-up**: Run a light test before heavy testing
5. **Intervals**: Allow time between tests for system recovery
6. **Documentation**: Save results for future comparisons
7. **Baseline**: Establish baseline metrics before making changes

## 🎯 Performance Objectives

### Development
- Requests/sec: > 100
- Failed requests: < 1%
- Avg response: < 100ms

### Staging
- Requests/sec: > 500
- Failed requests: < 0.1%
- Avg response: < 50ms

### Production
- Requests/sec: > 1000
- Failed requests: < 0.01%
- Avg response: < 30ms

## 📚 Additional Resources

- [Apache Bench Documentation](https://httpd.apache.org/docs/2.4/programs/ab.html)
- [Keycloak Performance Tuning](https://www.keycloak.org/docs/latest/server_installation/#_performance)
- [Grafana Dashboards](http://localhost:3000)
- [Prometheus Documentation](https://prometheus.io/docs/)

## 🔍 Example Test Session

```bash
# 1. Start production environment with monitoring
cd docker
./start.sh

# 2. Wait for services to be ready
docker ps

# 3. Run stress tests
cd ..
./scripts/stress-tests/run-stress-tests.sh

# Choose option 3 (Both tests)

# 4. Check results
cat stress-test-results/complete-*/combined-report.txt

# 5. View detailed metrics in Grafana
open http://localhost:3000

# 6. Query specific metrics in Prometheus
open http://localhost:9090
```

## 🛡️ Security Notes

- Scripts use demo credentials by default
- Never commit real credentials to version control
- Use environment variables for sensitive data
- For production testing, use service accounts
- Limit concurrent users to avoid DoS on production systems

