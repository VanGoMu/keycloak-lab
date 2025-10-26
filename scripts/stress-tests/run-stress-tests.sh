#!/bin/bash

# Combined Stress Test Runner
# Runs both Keycloak and FastAPI stress tests
# Uses Docker containers - no local installation required

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Navigate to root
cd "$(dirname "$0")/../.."

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Complete System Stress Test Suite               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Configuration
export CONCURRENT_USERS="${CONCURRENT_USERS:-10}"
export REQUESTS_PER_USER="${REQUESTS_PER_USER:-100}"
export KEYCLOAK_URL="${KEYCLOAK_URL:-https://host.docker.internal:8443}"
export FASTAPI_URL="${FASTAPI_URL:-http://host.docker.internal:8000}"
export REALM="${REALM:-demo-app}"
export CLIENT_ID="${CLIENT_ID:-demo-app-frontend}"
export USERNAME="${USERNAME:-demo-user}"
export PASSWORD="${PASSWORD:-Demo@User123}"

echo -e "${YELLOW}Test Configuration:${NC}"
echo "  Concurrent Users: $CONCURRENT_USERS"
echo "  Requests per User: $REQUESTS_PER_USER"
echo "  Total Requests: $((CONCURRENT_USERS * REQUESTS_PER_USER))"
echo ""
echo -e "${YELLOW}Targets:${NC}"
echo "  Keycloak: $KEYCLOAK_URL"
echo "  FastAPI: $FASTAPI_URL"
echo ""

# Check Docker availability
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    echo "Please install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

# Create main results directory
MAIN_RESULTS_DIR="stress-test-results/complete-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$MAIN_RESULTS_DIR"

# Make scripts executable
chmod +x scripts/stress-tests/*.sh

# Menu
echo -e "${BLUE}Select test to run:${NC}"
echo "  1) Keycloak only"
echo "  2) FastAPI only"
echo "  3) Both (sequential)"
echo "  4) Exit"
echo ""
read -p "Enter choice [1-4]: " choice

echo ""

# Ensure Docker images are available
echo -e "${YELLOW}Pulling required Docker images...${NC}"
docker pull httpd:alpine >/dev/null 2>&1 || true
docker pull curlimages/curl:latest >/dev/null 2>&1 || true
echo -e "${GREEN}Docker images ready${NC}"
echo ""

case $choice in
    1)
        echo -e "${GREEN}Running Keycloak stress test...${NC}"
        echo ""
        ./scripts/stress-tests/keycloak-stress-test.sh
        ;;
    2)
        echo -e "${GREEN}Running FastAPI stress test...${NC}"
        echo ""
        ./scripts/stress-tests/fastapi-stress-test.sh
        ;;
    3)
        echo -e "${GREEN}Running complete stress test suite...${NC}"
        echo ""
        
        # Run Keycloak test
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}  Phase 1: Keycloak Stress Test${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        ./scripts/stress-tests/keycloak-stress-test.sh
        
        echo ""
        echo -e "${YELLOW}Waiting 10 seconds before next test...${NC}"
        sleep 10
        echo ""
        
        # Run FastAPI test
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}  Phase 2: FastAPI Stress Test${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        ./scripts/stress-tests/fastapi-stress-test.sh
        
        # Generate combined report
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}  Generating Combined Report${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        # Find latest results
        LATEST_KEYCLOAK=$(ls -td stress-test-results/keycloak-* 2>/dev/null | head -1)
        LATEST_FASTAPI=$(ls -td stress-test-results/fastapi-* 2>/dev/null | head -1)
        
        cat > "$MAIN_RESULTS_DIR/combined-report.txt" << EOF
╔════════════════════════════════════════════════════════════╗
║          Complete System Stress Test Report               ║
╚════════════════════════════════════════════════════════════╝

Date: $(date)
Test Configuration:
  - Concurrent Users: $CONCURRENT_USERS
  - Requests per User: $REQUESTS_PER_USER
  - Total Requests per Test: $((CONCURRENT_USERS * REQUESTS_PER_USER))

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
KEYCLOAK RESULTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF
        if [ -n "$LATEST_KEYCLOAK" ] && [ -f "$LATEST_KEYCLOAK/summary.txt" ]; then
            tail -n +4 "$LATEST_KEYCLOAK/summary.txt" >> "$MAIN_RESULTS_DIR/combined-report.txt"
        else
            echo "No results found" >> "$MAIN_RESULTS_DIR/combined-report.txt"
        fi
        
        cat >> "$MAIN_RESULTS_DIR/combined-report.txt" << EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FASTAPI RESULTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF
        if [ -n "$LATEST_FASTAPI" ] && [ -f "$LATEST_FASTAPI/summary.txt" ]; then
            tail -n +4 "$LATEST_FASTAPI/summary.txt" >> "$MAIN_RESULTS_DIR/combined-report.txt"
        else
            echo "No results found" >> "$MAIN_RESULTS_DIR/combined-report.txt"
        fi
        
        cat >> "$MAIN_RESULTS_DIR/combined-report.txt" << EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SYSTEM METRICS (from Prometheus)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF
        
        # Try to get current metrics from Prometheus (using curl Docker image)
        if command -v docker &> /dev/null; then
            echo "JVM Memory Usage:" >> "$MAIN_RESULTS_DIR/combined-report.txt"
            docker run --rm --network host curlimages/curl:latest -s "http://localhost:9090/api/v1/query?query=jvm_memory_used_bytes{area=\"heap\"}" 2>/dev/null | \
                grep -o '"value":\[[^]]*\]' | grep -o '\[.*\]' | grep -o '[0-9.]*$' >> "$MAIN_RESULTS_DIR/combined-report.txt" 2>/dev/null || \
                echo "  Not available" >> "$MAIN_RESULTS_DIR/combined-report.txt"
            
            echo "" >> "$MAIN_RESULTS_DIR/combined-report.txt"
            echo "CPU Usage:" >> "$MAIN_RESULTS_DIR/combined-report.txt"
            docker run --rm --network host curlimages/curl:latest -s "http://localhost:9090/api/v1/query?query=process_cpu_usage" 2>/dev/null | \
                grep -o '"value":\[[^]]*\]' | grep -o '\[.*\]' | grep -o '[0-9.]*$' >> "$MAIN_RESULTS_DIR/combined-report.txt" 2>/dev/null || \
                echo "  Not available" >> "$MAIN_RESULTS_DIR/combined-report.txt"
            
            echo "" >> "$MAIN_RESULTS_DIR/combined-report.txt"
            echo "Active Database Connections:" >> "$MAIN_RESULTS_DIR/combined-report.txt"
            docker run --rm --network host curlimages/curl:latest -s "http://localhost:9090/api/v1/query?query=agroal_active_count" 2>/dev/null | \
                grep -o '"value":\[[^]]*\]' | grep -o '\[.*\]' | grep -o '[0-9.]*$' >> "$MAIN_RESULTS_DIR/combined-report.txt" 2>/dev/null || \
                echo "  Not available" >> "$MAIN_RESULTS_DIR/combined-report.txt"
        fi
        
        cat >> "$MAIN_RESULTS_DIR/combined-report.txt" << EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RECOMMENDATIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

View Grafana Dashboard: http://localhost:3000/d/keycloak-metrics
View Prometheus: http://localhost:9090

Detailed Results:
  - Keycloak: $LATEST_KEYCLOAK/
  - FastAPI: $LATEST_FASTAPI/

EOF
        
        cat "$MAIN_RESULTS_DIR/combined-report.txt"
        echo ""
        echo -e "${GREEN}✅ Complete report saved to: $MAIN_RESULTS_DIR/combined-report.txt${NC}"
        ;;
    4)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Stress Testing Complete                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Review results in stress-test-results/"
echo "  2. Check Grafana dashboard: http://localhost:3000/d/keycloak-metrics"
echo "  3. View Prometheus metrics: http://localhost:9090"
echo ""
