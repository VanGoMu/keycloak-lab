# FastAPI Keycloak Integration

OAuth2/OIDC integration demo with Keycloak identity provider.

## Features

- OAuth2 Authorization Code flow with PKCE
- JWT token validation and introspection
- Role-based access control (RBAC)
- User profile retrieval
- Protected API endpoints
- Token refresh workflow

## Quick Start

```bash
# Start Keycloak stack first
cd ../keycloak && ./start.sh

# Install dependencies
pip install -r requirements.txt

# Run application
uvicorn main:app --reload --port 8000
```

Access: http://localhost:8000

## Authentication Flow

```
User → /login → Keycloak login page
     → Authenticate → Redirect /callback?code=xxx
     → Exchange code for tokens → Protected resources
```

### Endpoints

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | `/` | Root endpoint | No |
| GET | `/login` | Initiate OAuth2 flow | No |
| GET | `/callback` | OAuth2 callback handler | No |
| GET | `/logout` | Session termination | No |
| GET | `/profile` | User profile (JWT claims) | Yes |
| GET | `/protected` | RBAC demo endpoint | Yes (user role) |
| GET | `/admin` | Admin-only endpoint | Yes (admin role) |
| GET | `/token-info` | Token introspection | Yes |

## Configuration

Environment variables (optional):

```bash
KEYCLOAK_URL=http://localhost:8080
REALM=demo-realm
CLIENT_ID=demo-client
CLIENT_SECRET=your-secret
REDIRECT_URI=http://localhost:8000/callback
```

Default client: `demo-client` (confidential, PKCE enabled)

## Token Validation

Two approaches implemented:

1. **JWT signature verification**: Local validation, faster
2. **Token introspection**: Remote validation, always accurate

```python
# JWT validation
decoded = jwt.decode(token, key=public_key, algorithms=["RS256"])

# Introspection
response = requests.post(f"{keycloak_url}/realms/{realm}/protocol/openid-connect/token/introspect")
```

## Role-Based Access Control

Demo realm users:

- **demo-user** / `demo` → `user` role → Access `/protected`
- **admin-user** / `admin` → `admin` role → Access `/admin`

Role mapping: `demo-client` → Role mappings → `user`, `admin`

Check roles in token claims:
```python
roles = token_data.get("resource_access", {}).get("demo-client", {}).get("roles", [])
```

## Testing

```bash
# Run test suite
./test.sh

# Manual testing
curl http://localhost:8000/
curl -H "Authorization: Bearer $TOKEN" http://localhost:8000/profile
```

Test scenarios:
- Unauthenticated access (401)
- Valid token access (200)
- Role-based filtering (403 if insufficient permissions)
- Token expiration (401)
- Token refresh

## Security Considerations

- **PKCE enabled**: Prevents authorization code interception
- **State parameter**: CSRF protection during OAuth flow
- **HTTPS required**: Production deployments must use TLS
- **Token storage**: Store access tokens securely (httpOnly cookies recommended)
- **Token lifetime**: Configure appropriate TTL in Keycloak
- **Scope validation**: Verify requested scopes match granted scopes

## Troubleshooting

**Issue**: 401 Unauthorized  
**Solution**: Check token expiration, verify `Authorization: Bearer <token>` header

**Issue**: 403 Forbidden on `/admin`  
**Solution**: Ensure user has `admin` role mapped in Keycloak client

**Issue**: Invalid redirect_uri  
**Solution**: Add `http://localhost:8000/*` to valid redirect URIs in Keycloak client settings

**Issue**: Token validation fails  
**Solution**: Verify Keycloak realm public key matches validation key

## Production Deployment

- Use environment variables for configuration
- Enable HTTPS/TLS
- Configure token lifetimes (access: 5min, refresh: 30min)
- Implement token refresh logic
- Add rate limiting
- Monitor token introspection endpoint usage
- Use Redis for session storage (distributed deployments)

## References

- [Keycloak Admin Console](http://localhost:8080/admin) (admin/admin)
- [OpenID Connect Discovery](http://localhost:8080/realms/demo-realm/.well-known/openid-configuration)
- [FastAPI OAuth2 Documentation](https://fastapi.tiangolo.com/tutorial/security/oauth2-jwt/)
