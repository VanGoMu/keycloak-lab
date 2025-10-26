# Using Keycloak - A Beginner's Guide

This guide explains how to use Keycloak for authentication and authorization in your applications.

## Table of Contents

1. [What is Keycloak?](#what-is-keycloak)
2. [Basic Concepts](#basic-concepts)
3. [Getting Started](#getting-started)
4. [Creating Your First Realm](#creating-your-first-realm)
5. [Managing Users](#managing-users)
6. [Creating Clients (Applications)](#creating-clients-applications)
7. [Understanding Roles](#understanding-roles)
8. [Integrating with Your Application](#integrating-with-your-application)
9. [Common Use Cases](#common-use-cases)
10. [Troubleshooting](#troubleshooting)

---

## What is Keycloak?

Keycloak is an **open-source Identity and Access Management (IAM)** solution. Think of it as a security guard for your applications that:

- **Authenticates users** (verifies who they are)
- **Authorizes users** (controls what they can do)
- **Manages user sessions** (keeps track of logged-in users)
- **Provides Single Sign-On (SSO)** (log in once, access multiple apps)

### Why Use Keycloak?

Instead of building your own login system, Keycloak provides:
- ✅ User registration and login
- ✅ Password reset and email verification
- ✅ Two-factor authentication (2FA)
- ✅ Social login (Google, Facebook, etc.)
- ✅ Role-based access control (RBAC)
- ✅ OAuth 2.0 and OpenID Connect support

---

## Basic Concepts

### 1. **Realm**
A realm is a **container** that manages users, credentials, roles, and applications. Think of it as a separate workspace.

- **Example**: You might have a `production` realm for your live app and a `demo` realm for testing.

### 2. **User**
A person who can log in to your applications. Each user has:
- Username
- Password
- Email
- Assigned roles

### 3. **Client**
A **client** represents an application (web app, mobile app, API) that uses Keycloak for authentication.

- **Example**: Your React frontend is a client, your FastAPI backend is another client.

### 4. **Role**
A **role** defines what a user can do. Roles are used for authorization.

- **Example**: `admin` role can delete users, `user` role can only view their profile.

### 5. **Token**
A **token** is a secure credential that proves a user is authenticated. Your app receives a token after successful login and uses it to access protected resources.

---

## Getting Started

### Accessing Keycloak Admin Console

#### Development Environment
```bash
# Start the development environment
cd docker
docker compose -f docker-compose.dev.yml up -d

# Access the Admin Console
# URL: http://localhost:8080/admin
# Username: keycloak_admin (from docker/.env)
# Password: keycloak@pass123StrNG (from docker/.env)
```

#### Production Environment
```bash
# Start the production environment
cd docker
docker compose -f docker-compose.prod.yml up -d

# Access the Admin Console
# URL: https://localhost:8443/admin
# Username: keycloak_admin (from docker/.env)
# Password: keycloak@pass123StrNG (from docker/.env)
```

---

## Creating Your First Realm

A realm is like a separate workspace for managing users and applications.

### Step-by-Step:

1. **Log in to Admin Console**
   - Navigate to `http://localhost:8080/admin` (dev) or `https://localhost:8443/admin` (prod)
   - Enter admin credentials

2. **Create a New Realm**
   - Click the **dropdown** in the top-left corner (next to "master")
   - Click **"Create Realm"**
   - Enter a realm name (e.g., `my-app`)
   - Click **"Create"**

3. **Configure Realm Settings** (Optional)
   - Go to **Realm Settings** → **General**
   - Set a display name: `My Application`
   - Enable user registration if needed
   - Enable email verification if needed

### Using the Pre-configured `demo-app` Realm

This lab already includes a configured realm:

```json
Realm Name: demo-app
Display Name: Demo Application
Users: demo-user, admin-user
Clients: demo-app-frontend, demo-app-backend
```

---

## Managing Users

### Creating a User

1. **Navigate to Users**
   - Select your realm (e.g., `demo-app`)
   - Click **"Users"** in the left sidebar
   - Click **"Add user"**

2. **Fill in User Details**
   ```
   Username: john.doe
   Email: john.doe@example.com
   First Name: John
   Last Name: Doe
   Email Verified: ON
   Enabled: ON
   ```

3. **Set Password**
   - Click on the newly created user
   - Go to the **"Credentials"** tab
   - Click **"Set password"**
   - Enter password: `MySecurePass123!`
   - Toggle **"Temporary"** to OFF (user won't be forced to change password)
   - Click **"Save"**

### Using Pre-configured Demo Users

This lab includes two pre-configured users:

#### Demo User (Regular User)
```
Username: demo-user
Password: Demo@User123 (from docker/.env)
Email: demo@example.com
Roles: user
```

#### Admin User (Administrator)
```
Username: admin-user
Password: Admin@User123 (from docker/.env)
Email: admin@example.com
Roles: admin, user
```

### Testing User Login (via API)

```bash
# Source environment variables
source docker/.env

# Development environment
curl -s -X POST "http://localhost:8080/realms/demo-app/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=demo-user" \
  -d "password=${DEMO_USER_PASSWORD}" \
  -d "grant_type=password" \
  -d "client_id=demo-app-frontend" | jq

# Production environment
curl -k -s -X POST "https://localhost:8443/realms/demo-app/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=demo-user" \
  -d "password=${DEMO_USER_PASSWORD}" \
  -d "grant_type=password" \
  -d "client_id=demo-app-frontend" | jq
```

You should receive an `access_token` in the response.

---

## Creating Clients (Applications)

A **client** represents your application that will use Keycloak for authentication.

### Types of Clients

1. **Public Client** (e.g., React, Vue, Angular)
   - Runs in the browser
   - Cannot keep secrets secure
   - Uses PKCE for security

2. **Confidential Client** (e.g., Backend API, Server-side app)
   - Runs on a server
   - Can keep secrets secure
   - Uses client_secret

### Creating a Public Client (Frontend App)

1. **Navigate to Clients**
   - Select your realm
   - Click **"Clients"** in the left sidebar
   - Click **"Create client"**

2. **General Settings**
   ```
   Client type: OpenID Connect
   Client ID: my-frontend-app
   Name: My Frontend Application
   ```
   Click **"Next"**

3. **Capability Config**
   ```
   Client authentication: OFF (for public clients)
   Authorization: OFF
   Authentication flow:
     ✓ Standard flow
     ✓ Direct access grants
   ```
   Click **"Next"**

4. **Login Settings**
   ```
   Root URL: http://localhost:3000
   Valid redirect URIs: http://localhost:3000/*
   Valid post logout redirect URIs: http://localhost:3000
   Web origins: http://localhost:3000
   ```
   Click **"Save"**

### Creating a Confidential Client (Backend API)

1. **General Settings**
   ```
   Client type: OpenID Connect
   Client ID: my-backend-api
   Name: My Backend API
   ```

2. **Capability Config**
   ```
   Client authentication: ON (for confidential clients)
   Authorization: ON (if you need fine-grained permissions)
   Authentication flow:
     ✓ Service accounts roles
   ```

3. **After Creation**
   - Go to **"Credentials"** tab
   - Copy the **Client Secret** (you'll need this in your backend)

### Pre-configured Clients in `demo-app`

```
Client ID: demo-app-frontend
Type: Public
Purpose: Frontend application (React, Vue, etc.)

Client ID: demo-app-backend
Type: Confidential
Purpose: Backend API
```

---

## Understanding Roles

Roles define **what users can do** in your application.

### Types of Roles

1. **Realm Roles** - Available across all clients in the realm
2. **Client Roles** - Specific to a single client

### Creating a Realm Role

1. **Navigate to Realm Roles**
   - Select your realm
   - Click **"Realm roles"** in the left sidebar
   - Click **"Create role"**

2. **Create Role**
   ```
   Role name: premium-user
   Description: Users with premium subscription
   ```
   Click **"Save"**

### Assigning Roles to Users

1. **Navigate to User**
   - Go to **"Users"** → Select user → **"Role mapping"** tab

2. **Assign Role**
   - Click **"Assign role"**
   - Select the role (e.g., `premium-user`)
   - Click **"Assign"**

### Pre-configured Roles in `demo-app`

```
Realm Roles:
  - user: Basic user access
  - admin: Administrative access

User Assignments:
  - demo-user: user
  - admin-user: admin, user
```

---

## Integrating with Your Application

### Frontend Integration (JavaScript)

#### Install Keycloak JS Adapter

```bash
npm install keycloak-js
```

#### Initialize Keycloak

```javascript
import Keycloak from 'keycloak-js';

const keycloak = new Keycloak({
  url: 'http://localhost:8080',
  realm: 'demo-app',
  clientId: 'demo-app-frontend'
});

// Initialize and login
keycloak.init({ onLoad: 'login-required' }).then(authenticated => {
  if (authenticated) {
    console.log('User is authenticated');
    console.log('Access Token:', keycloak.token);
    console.log('User Info:', keycloak.tokenParsed);
  } else {
    console.log('User is not authenticated');
  }
}).catch(err => {
  console.error('Failed to initialize:', err);
});
```

#### Making Authenticated API Calls

```javascript
// Add token to API requests
fetch('http://localhost:8000/api/protected', {
  headers: {
    'Authorization': `Bearer ${keycloak.token}`
  }
})
.then(response => response.json())
.then(data => console.log(data));
```

#### Logout

```javascript
keycloak.logout({ redirectUri: 'http://localhost:3000' });
```

### Backend Integration (Python/FastAPI)

#### Install Dependencies

```bash
pip install python-keycloak requests
```

#### Verify Token

```python
from fastapi import FastAPI, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthCredentials
import requests

app = FastAPI()
security = HTTPBearer()

KEYCLOAK_URL = "http://localhost:8080"
REALM = "demo-app"

def verify_token(credentials: HTTPAuthCredentials = Depends(security)):
    """Verify JWT token with Keycloak"""
    token = credentials.credentials
    
    # Introspect token
    url = f"{KEYCLOAK_URL}/realms/{REALM}/protocol/openid-connect/token/introspect"
    response = requests.post(
        url,
        data={
            "token": token,
            "client_id": "demo-app-backend"
        }
    )
    
    result = response.json()
    
    if not result.get("active"):
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    
    return result

@app.get("/protected")
async def protected_route(token_info: dict = Depends(verify_token)):
    """Protected endpoint that requires authentication"""
    return {
        "message": "You have access!",
        "username": token_info.get("preferred_username"),
        "roles": token_info.get("realm_access", {}).get("roles", [])
    }
```

#### Check User Roles

```python
def require_role(required_role: str):
    """Dependency to check if user has required role"""
    def role_checker(token_info: dict = Depends(verify_token)):
        roles = token_info.get("realm_access", {}).get("roles", [])
        if required_role not in roles:
            raise HTTPException(status_code=403, detail="Insufficient permissions")
        return token_info
    return role_checker

@app.delete("/admin/users/{user_id}")
async def delete_user(user_id: str, token_info: dict = Depends(require_role("admin"))):
    """Only users with 'admin' role can access this"""
    return {"message": f"User {user_id} deleted"}
```

### Example: Complete React App

```javascript
import React, { useEffect, useState } from 'react';
import Keycloak from 'keycloak-js';

const keycloak = new Keycloak({
  url: 'http://localhost:8080',
  realm: 'demo-app',
  clientId: 'demo-app-frontend'
});

function App() {
  const [authenticated, setAuthenticated] = useState(false);
  const [userInfo, setUserInfo] = useState(null);

  useEffect(() => {
    keycloak.init({ onLoad: 'check-sso' }).then(auth => {
      setAuthenticated(auth);
      if (auth) {
        keycloak.loadUserInfo().then(info => {
          setUserInfo(info);
        });
      }
    });
  }, []);

  if (!authenticated) {
    return (
      <div>
        <h1>Welcome</h1>
        <button onClick={() => keycloak.login()}>Login</button>
      </div>
    );
  }

  return (
    <div>
      <h1>Welcome, {userInfo?.preferred_username}!</h1>
      <p>Email: {userInfo?.email}</p>
      <button onClick={() => keycloak.logout()}>Logout</button>
    </div>
  );
}

export default App;
```

---

## Common Use Cases

### 1. **User Registration with Email Verification**

Enable in Keycloak:
1. Go to **Realm Settings** → **Login**
2. Enable **"User registration"**
3. Enable **"Verify email"**
4. Configure SMTP settings in **Realm Settings** → **Email**

### 2. **Password Reset**

Users can reset their password:
1. On login page, click **"Forgot password?"**
2. Enter email address
3. Keycloak sends reset link
4. User sets new password

### 3. **Social Login (Google, Facebook)**

1. Go to **Identity Providers**
2. Select provider (e.g., Google)
3. Enter Client ID and Secret from Google Console
4. Save and test

### 4. **Two-Factor Authentication (2FA)**

1. Go to **Authentication** → **Required Actions**
2. Enable **"Configure OTP"**
3. Users will be prompted to set up 2FA on next login

### 5. **Single Sign-On (SSO)**

Users log in once and access multiple applications:
- All apps must use the same Keycloak realm
- Users stay logged in across all apps
- Logout from one app logs out from all

### 6. **API Protection**

Protect your API endpoints:

```python
# Only authenticated users
@app.get("/api/profile")
async def get_profile(token: dict = Depends(verify_token)):
    return {"user": token["preferred_username"]}

# Only admin users
@app.post("/api/admin/settings")
async def update_settings(token: dict = Depends(require_role("admin"))):
    return {"message": "Settings updated"}
```

---

## Troubleshooting

### Common Issues

#### 1. **"Invalid user credentials" Error**

**Problem**: User exists but can't log in.

**Solution**:
- Check password is set correctly
- Verify user is enabled
- Check email is verified (if required)
- Ensure realm name is correct

```bash
# Reset user password via API
source docker/.env
ACCESS_TOKEN=$(curl -k -s -X POST "https://localhost:8443/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli" \
  -d "username=${KC_ADMIN_USERNAME}" \
  -d "password=${KC_ADMIN_PASSWORD}" \
  -d "grant_type=password" | jq -r '.access_token')

USER_ID=$(curl -k -s -H "Authorization: Bearer $ACCESS_TOKEN" \
  "https://localhost:8443/admin/realms/demo-app/users?username=demo-user&exact=true" | jq -r '.[0].id')

curl -k -X PUT "https://localhost:8443/admin/realms/demo-app/users/$USER_ID/reset-password" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type":"password","value":"NewPassword123!","temporary":false}'
```

#### 2. **CORS Errors in Browser**

**Problem**: Browser blocks requests due to CORS policy.

**Solution**:
- Go to **Clients** → Select your client
- Add your app's URL to **Web Origins** (e.g., `http://localhost:3000`)
- Use `*` for development only (not production!)

#### 3. **"Invalid redirect URI" Error**

**Problem**: Keycloak rejects redirect after login.

**Solution**:
- Go to **Clients** → Select your client
- Add your redirect URI to **Valid Redirect URIs** (e.g., `http://localhost:3000/*`)
- Make sure to include the wildcard `*` or exact path

#### 4. **Token Expired**

**Problem**: Access token expires after short time.

**Solution**:
- Go to **Realm Settings** → **Tokens**
- Increase **Access Token Lifespan** (default is 5 minutes)
- Implement token refresh in your app:

```javascript
// Auto-refresh token before expiration
setInterval(() => {
  keycloak.updateToken(70) // Refresh if expires in < 70 seconds
    .then(refreshed => {
      if (refreshed) {
        console.log('Token refreshed');
      }
    })
    .catch(() => {
      console.error('Failed to refresh token');
      keycloak.login();
    });
}, 60000); // Check every minute
```

#### 5. **Users Not Created on Realm Import**

**Problem**: Realm imports with `IGNORE_EXISTING` strategy skip users.

**Solution**:
- Create users manually via Admin Console
- Or create users via script:

```bash
# Use the create-demo-user.sh script
./scripts/stress-tests/create-demo-user.sh
```

---

## Quick Reference

### Important URLs

| Environment | Admin Console | Realm Endpoint |
|------------|---------------|----------------|
| Development | http://localhost:8080/admin | http://localhost:8080/realms/demo-app |
| Production | https://localhost:8443/admin | https://localhost:8443/realms/demo-app |

### Common Endpoints

```bash
# Token endpoint (get access token)
POST /realms/{realm}/protocol/openid-connect/token

# User info (get user details)
GET /realms/{realm}/protocol/openid-connect/userinfo

# JWKS (public keys for token verification)
GET /realms/{realm}/protocol/openid-connect/certs

# OpenID configuration (discover all endpoints)
GET /realms/{realm}/.well-known/openid-configuration
```

### Test Scripts

```bash
# Run development tests
./scripts/dev/test.sh

# Run production tests
./scripts/prod/test.sh

# Create demo users
./scripts/stress-tests/create-demo-user.sh
```

### Environment Variables

All credentials are in `docker/.env`:

```bash
# Admin credentials
KC_ADMIN_USERNAME=keycloak_admin
KC_ADMIN_PASSWORD=keycloak@pass123StrNG

# Demo user credentials
DEMO_USER_PASSWORD=Demo@User123
ADMIN_USER_PASSWORD=Admin@User123
```

---

## Next Steps

1. **Explore the Admin Console**
   - Create test users
   - Try different roles
   - Configure email settings

2. **Build a Simple App**
   - Create a client in Keycloak
   - Use the JavaScript adapter
   - Protect API endpoints

3. **Read Official Documentation**
   - [Keycloak Documentation](https://www.keycloak.org/documentation)
   - [Server Admin Guide](https://www.keycloak.org/docs/latest/server_admin/)
   - [Securing Applications](https://www.keycloak.org/docs/latest/securing_apps/)

4. **Check Our Examples**
   - See `keycloak/examples/` for integration examples
   - Review `fast-api-app/main.py` for FastAPI integration
   - Check `docs/DISASTER_RECOVERY.md` for backup/restore procedures

---

## Need Help?

- **Check logs**: `docker compose -f docker-compose.dev.yml logs -f keycloak-dev`
- **Test connectivity**: `curl -s http://localhost:8080/health`
- **Verify users exist**: Check Admin Console → Users
- **Review test scripts**: `./scripts/dev/test.sh` or `./scripts/prod/test.sh`

Happy authenticating! 🔐
