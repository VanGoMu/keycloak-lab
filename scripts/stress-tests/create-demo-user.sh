#!/bin/bash

# Script to create demo-user in demo-app realm
# Run this after Keycloak is fully started

set -e

# Load environment variables from docker/.env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../../docker/.env"

if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "⚠️  Warning: docker/.env not found, using default values"
fi

# Set credentials from environment or use defaults
KC_ADMIN_USERNAME="${KC_ADMIN_USERNAME:-admin}"
KC_ADMIN_PASSWORD="${KC_ADMIN_PASSWORD:-admin}"
DEMO_USER_PASSWORD="${DEMO_USER_PASSWORD:-DemoUser123}"

echo "🔑 Creating demo-user in Keycloak..."

# Wait for Keycloak to be ready
echo "Waiting for Keycloak to be ready..."
MAX_ATTEMPTS=30
ATTEMPT=0
until curl -k -sf https://localhost:8443/realms/master > /dev/null 2>&1; do
    ATTEMPT=$((ATTEMPT + 1))
    if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
        echo ""
        echo "❌ Keycloak did not become ready in time"
        exit 1
    fi
    echo -n "."
    sleep 2
done
echo " ✅"

# Get admin token
echo "Getting admin access token..."
ADMIN_TOKEN=$(curl -k -s -X POST "https://localhost:8443/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=admin-cli" \
  -d "username=${KC_ADMIN_USERNAME}" \
  -d "password=${KC_ADMIN_PASSWORD}" \
  -d "grant_type=password" | jq -r '.access_token')

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" == "null" ]; then
    echo "❌ Failed to get admin token"
    exit 1
fi
echo "✅ Got admin token"

# Check if user already exists
echo "Checking if demo-user already exists..."
USER_ID=$(curl -k -s "https://localhost:8443/admin/realms/demo-app/users?username=demo-user&exact=true" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq -r '.[0].id // empty')

if [ -n "$USER_ID" ]; then
    echo "⚠️  User demo-user already exists (ID: $USER_ID)"
    echo "Updating password..."
    
    # Reset password
    curl -k -s -X PUT "https://localhost:8443/admin/realms/demo-app/users/$USER_ID/reset-password" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{
        "type": "password",
        "value": "'"${DEMO_USER_PASSWORD}"'",
        "temporary": false
      }'
    
    echo "✅ Password updated for demo-user"
else
    echo "Creating new user demo-user..."
    
    # Create user
    curl -k -s -X POST "https://localhost:8443/admin/realms/demo-app/users" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{
        "username": "demo-user",
        "enabled": true,
        "emailVerified": true,
        "firstName": "Demo",
        "lastName": "User",
        "email": "demo@example.com",
        "credentials": [{
          "type": "password",
          "value": "'"${DEMO_USER_PASSWORD}"'",
          "temporary": false
        }]
      }'
    
    echo "✅ User demo-user created"
    
    # Get user ID
    USER_ID=$(curl -k -s "https://localhost:8443/admin/realms/demo-app/users?username=demo-user&exact=true" \
      -H "Authorization: Bearer $ADMIN_TOKEN" | jq -r '.[0].id')
fi

# Assign user role
echo "Assigning 'user' role..."
ROLE_ID=$(curl -k -s "https://localhost:8443/admin/realms/demo-app/roles" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq -r '.[] | select(.name=="user") | .id')

if [ -n "$ROLE_ID" ]; then
    curl -k -s -X POST "https://localhost:8443/admin/realms/demo-app/users/$USER_ID/role-mappings/realm" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d '[{
        "id": "'"$ROLE_ID"'",
        "name": "user"
      }]'
    echo "✅ Role assigned"
else
    echo "⚠️  Role 'user' not found"
fi

# Test credentials
echo ""
echo "🧪 Testing credentials..."
TOKEN=$(curl -k -s -X POST "https://localhost:8443/realms/demo-app/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=demo-user" \
  -d "password=${DEMO_USER_PASSWORD}" \
  -d "grant_type=password" \
  -d "client_id=demo-app-frontend" | jq -r '.access_token // empty')

if [ -n "$TOKEN" ]; then
    echo "✅ Login successful! User demo-user is ready to use."
    echo "   Username: demo-user"
    echo "   Password: ${DEMO_USER_PASSWORD}"
else
    echo "❌ Login failed - please check configuration"
    exit 1
fi
