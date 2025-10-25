"""
Ejemplo de integración de Keycloak con Python FastAPI
pip install fastapi uvicorn python-jose[cryptography] requests
"""

from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from jose import jwt, JWTError
from typing import Optional, List
import requests
from functools import wraps

app = FastAPI(title="API con Keycloak")

# Configuración de CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuración de Keycloak
KEYCLOAK_URL = "http://localhost:8080"
REALM = "demo-app"
CLIENT_ID = "demo-app-backend"
CLIENT_SECRET = "demo-app-backend-secret-change-me"

# Security scheme
security = HTTPBearer()

# Obtener configuración de Keycloak (JWKS)
def get_keycloak_public_key():
    """Obtiene la clave pública de Keycloak para validar tokens"""
    try:
        response = requests.get(
            f"{KEYCLOAK_URL}/realms/{REALM}/protocol/openid-connect/certs"
        )
        return response.json()
    except Exception as e:
        print(f"Error obteniendo clave pública: {e}")
        return None

def decode_token(token: str) -> dict:
    """Decodifica y valida el token JWT"""
    try:
        # Obtener configuración de OIDC
        oidc_config_url = f"{KEYCLOAK_URL}/realms/{REALM}/.well-known/openid-configuration"
        oidc_config = requests.get(oidc_config_url).json()
        
        # Obtener JWKS
        jwks_uri = oidc_config["jwks_uri"]
        jwks = requests.get(jwks_uri).json()
        
        # Decodificar token
        # En producción, agregar validación de audience, issuer, etc.
        payload = jwt.decode(
            token,
            jwks,
            algorithms=["RS256"],
            audience=CLIENT_ID,
            options={"verify_signature": True, "verify_aud": False}
        )
        
        return payload
    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Token inválido: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )

def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict:
    """Dependency para obtener el usuario actual desde el token"""
    token = credentials.credentials
    return decode_token(token)

def require_role(required_roles: List[str]):
    """Decorator para requerir roles específicos"""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Obtener current_user de los kwargs
            current_user = kwargs.get('current_user')
            if not current_user:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="No autenticado"
                )
            
            # Verificar roles
            user_roles = current_user.get("realm_access", {}).get("roles", [])
            has_required_role = any(role in user_roles for role in required_roles)
            
            if not has_required_role:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"Se requiere uno de estos roles: {', '.join(required_roles)}"
                )
            
            return await func(*args, **kwargs)
        return wrapper
    return decorator

# ============================================
# ENDPOINTS
# ============================================

@app.get("/")
def read_root():
    """Endpoint público"""
    return {"message": "API con Keycloak funcionando"}

@app.get("/api/public/info")
def public_info():
    """Endpoint público - no requiere autenticación"""
    return {
        "message": "Este es un endpoint público",
        "keycloak_url": KEYCLOAK_URL,
        "realm": REALM
    }

@app.get("/api/protected/profile")
def get_profile(current_user: dict = Depends(get_current_user)):
    """Endpoint protegido - requiere autenticación"""
    return {
        "username": current_user.get("preferred_username"),
        "email": current_user.get("email"),
        "name": current_user.get("name"),
        "roles": current_user.get("realm_access", {}).get("roles", []),
        "email_verified": current_user.get("email_verified"),
    }

@app.get("/api/user/data")
def get_user_data(current_user: dict = Depends(get_current_user)):
    """Endpoint para usuarios con rol 'user'"""
    user_roles = current_user.get("realm_access", {}).get("roles", [])
    
    if "user" not in user_roles and "admin" not in user_roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Se requiere rol 'user' o 'admin'"
        )
    
    return {
        "message": "Datos de usuario",
        "user": current_user.get("preferred_username"),
        "data": ["item1", "item2", "item3"]
    }

@app.get("/api/admin/users")
def get_all_users(current_user: dict = Depends(get_current_user)):
    """Endpoint solo para administradores"""
    user_roles = current_user.get("realm_access", {}).get("roles", [])
    
    if "admin" not in user_roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Se requiere rol 'admin'"
        )
    
    return {
        "message": "Lista de usuarios (solo admin)",
        "admin": current_user.get("preferred_username"),
        "users": [
            {"id": 1, "name": "Usuario 1"},
            {"id": 2, "name": "Usuario 2"},
        ]
    }

@app.post("/api/user/create")
def create_user_data(
    data: dict,
    current_user: dict = Depends(get_current_user)
):
    """Crear datos de usuario"""
    return {
        "message": "Datos creados",
        "created_by": current_user.get("preferred_username"),
        "data": data
    }

# ============================================
# UTILIDADES PARA INTEGRACIÓN CON KEYCLOAK
# ============================================

class KeycloakAdmin:
    """Cliente para administración de Keycloak"""
    
    def __init__(self):
        self.base_url = KEYCLOAK_URL
        self.realm = REALM
        self.client_id = CLIENT_ID
        self.client_secret = CLIENT_SECRET
        self.token = None
    
    def get_admin_token(self):
        """Obtiene token de administración"""
        url = f"{self.base_url}/realms/{self.realm}/protocol/openid-connect/token"
        data = {
            "client_id": self.client_id,
            "client_secret": self.client_secret,
            "grant_type": "client_credentials"
        }
        response = requests.post(url, data=data)
        response.raise_for_status()
        self.token = response.json()["access_token"]
        return self.token
    
    def get_users(self):
        """Obtiene lista de usuarios del realm"""
        if not self.token:
            self.get_admin_token()
        
        url = f"{self.base_url}/admin/realms/{self.realm}/users"
        headers = {"Authorization": f"Bearer {self.token}"}
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        return response.json()
    
    def create_user(self, username: str, email: str, password: str):
        """Crea un nuevo usuario"""
        if not self.token:
            self.get_admin_token()
        
        url = f"{self.base_url}/admin/realms/{self.realm}/users"
        headers = {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json"
        }
        user_data = {
            "username": username,
            "email": email,
            "enabled": True,
            "emailVerified": True,
            "credentials": [{
                "type": "password",
                "value": password,
                "temporary": False
            }]
        }
        response = requests.post(url, headers=headers, json=user_data)
        response.raise_for_status()
        return response.status_code == 201

@app.get("/api/admin/keycloak/users")
def list_keycloak_users(current_user: dict = Depends(get_current_user)):
    """Listar usuarios desde Keycloak Admin API"""
    user_roles = current_user.get("realm_access", {}).get("roles", [])
    
    if "admin" not in user_roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Se requiere rol 'admin'"
        )
    
    kc_admin = KeycloakAdmin()
    users = kc_admin.get_users()
    return {"users": users}

# ============================================
# INICIAR SERVIDOR
# ============================================

if __name__ == "__main__":
    import uvicorn
    print("🚀 Iniciando API con Keycloak en http://localhost:8000")
    print("📚 Documentación en http://localhost:8000/docs")
    uvicorn.run(app, host="0.0.0.0", port=8000)

"""
EJEMPLO DE USO CON CURL:

# 1. Obtener token de Keycloak
curl -X POST 'http://localhost:8080/realms/demo-app/protocol/openid-connect/token' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'client_id=demo-app-backend' \
  -d 'client_secret=demo-app-backend-secret-change-me' \
  -d 'grant_type=password' \
  -d 'username=demo-user' \
  -d 'password=demo123'

# 2. Usar el token en las peticiones
curl -X GET 'http://localhost:8000/api/protected/profile' \
  -H 'Authorization: Bearer <ACCESS_TOKEN>'

# 3. Endpoint de admin
curl -X GET 'http://localhost:8000/api/admin/users' \
  -H 'Authorization: Bearer <ACCESS_TOKEN>'
"""

"""
EJEMPLO DE CLIENTE PYTHON:

import requests

# 1. Obtener token
def get_token(username, password):
    url = 'http://localhost:8080/realms/demo-app/protocol/openid-connect/token'
    data = {
        'client_id': 'demo-app-backend',
        'client_secret': 'demo-app-backend-secret-change-me',
        'grant_type': 'password',
        'username': username,
        'password': password
    }
    response = requests.post(url, data=data)
    return response.json()['access_token']

# 2. Hacer petición autenticada
token = get_token('demo-user', 'demo123')
headers = {'Authorization': f'Bearer {token}'}

response = requests.get('http://localhost:8000/api/protected/profile', headers=headers)
print(response.json())
"""
