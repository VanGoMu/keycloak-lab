"""
FastAPI Application Integrada con Keycloak
==========================================

Esta aplicación demuestra cómo integrar FastAPI con Keycloak para:
- Autenticación OAuth 2.0 / OpenID Connect
- Endpoints públicos y protegidos
- Validación de tokens JWT
- Autorización basada en roles
"""

from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import OAuth2AuthorizationCodeBearer, HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, RedirectResponse
from jose import jwt, JWTError
from typing import Optional, List, Dict, Any
import requests
from pydantic import BaseModel
import os

# ============================================
# CONFIGURACIÓN
# ============================================

KEYCLOAK_URL = os.getenv("KEYCLOAK_URL", "http://localhost:8080")
REALM = os.getenv("KEYCLOAK_REALM", "demo-app")
CLIENT_ID = os.getenv("KEYCLOAK_CLIENT_ID", "demo-app-frontend")
CLIENT_SECRET = os.getenv("KEYCLOAK_CLIENT_SECRET", "")  # Solo si es confidencial

# URLs de Keycloak
KEYCLOAK_BASE = f"{KEYCLOAK_URL}/realms/{REALM}"
OIDC_CONFIG_URL = f"{KEYCLOAK_BASE}/.well-known/openid-configuration"
TOKEN_URL = f"{KEYCLOAK_BASE}/protocol/openid-connect/token"
USERINFO_URL = f"{KEYCLOAK_BASE}/protocol/openid-connect/userinfo"
JWKS_URL = f"{KEYCLOAK_BASE}/protocol/openid-connect/certs"
AUTH_URL = f"{KEYCLOAK_BASE}/protocol/openid-connect/auth"
LOGOUT_URL = f"{KEYCLOAK_BASE}/protocol/openid-connect/logout"

# ============================================
# INICIALIZACIÓN DE FASTAPI
# ============================================

app = FastAPI(
    title="FastAPI + Keycloak Demo",
    description="Aplicación de ejemplo con autenticación Keycloak",
    version="1.0.0"
)

# CORS para permitir requests desde el frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:8000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security schemes
http_bearer = HTTPBearer()

# ============================================
# MODELOS PYDANTIC
# ============================================

class UserInfo(BaseModel):
    """Información del usuario autenticado"""
    username: str
    email: Optional[str] = None
    name: Optional[str] = None
    roles: List[str] = []
    sub: str

class TokenResponse(BaseModel):
    """Respuesta del endpoint de token"""
    access_token: str
    refresh_token: Optional[str]
    token_type: str
    expires_in: int

class LoginRequest(BaseModel):
    """Request para login con usuario y contraseña"""
    username: str
    password: str

# ============================================
# FUNCIONES AUXILIARES
# ============================================

def get_jwks() -> Dict:
    """Obtiene las claves públicas de Keycloak (JWKS)"""
    try:
        response = requests.get(JWKS_URL)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"Error obteniendo JWKS: {e}")
        return {}

def decode_token(token: str) -> Dict[str, Any]:
    """
    Decodifica y valida el token JWT de Keycloak
    
    Args:
        token: Token JWT en formato string
        
    Returns:
        Dict con los claims del token
        
    Raises:
        HTTPException: Si el token es inválido
    """
    try:
        # Obtener JWKS
        jwks = get_jwks()
        
        # Decodificar sin verificar primero para obtener el header
        unverified_header = jwt.get_unverified_header(token)
        
        # Buscar la clave correcta en JWKS
        rsa_key = {}
        for key in jwks.get("keys", []):
            if key["kid"] == unverified_header["kid"]:
                rsa_key = {
                    "kty": key["kty"],
                    "kid": key["kid"],
                    "use": key["use"],
                    "n": key["n"],
                    "e": key["e"]
                }
                break
        
        if not rsa_key:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="No se pudo validar el token - clave no encontrada",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        # Decodificar y validar el token
        payload = jwt.decode(
            token,
            rsa_key,
            algorithms=["RS256"],
            audience="account",  # Keycloak usa "account" como audience por defecto
            options={"verify_aud": False}  # Desactivar por ahora para simplificar
        )
        
        return payload
        
    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Token inválido: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Error validando token: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )

# ============================================
# DEPENDENCIES
# ============================================

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(http_bearer)) -> UserInfo:
    """
    Dependency que obtiene el usuario actual desde el token JWT
    
    Uso:
        @app.get("/protected")
        async def protected_route(user: UserInfo = Depends(get_current_user)):
            return {"message": f"Hola {user.username}"}
    """
    token = credentials.credentials
    payload = decode_token(token)
    
    # Extraer información del usuario
    user = UserInfo(
        username=payload.get("preferred_username", "unknown"),
        email=payload.get("email"),
        name=payload.get("name"),
        roles=payload.get("realm_access", {}).get("roles", []),
        sub=payload.get("sub")
    )
    
    return user

def require_role(required_roles: List[str]):
    """
    Dependency factory para requerir roles específicos
    
    Uso:
        @app.get("/admin")
        async def admin_only(user: UserInfo = Depends(require_role(["admin"]))):
            return {"message": "Área de admin"}
    """
    async def role_checker(user: UserInfo = Depends(get_current_user)) -> UserInfo:
        if not any(role in user.roles for role in required_roles):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Se requiere uno de estos roles: {', '.join(required_roles)}"
            )
        return user
    return role_checker

# ============================================
# ENDPOINTS PÚBLICOS
# ============================================

@app.get("/", response_class=HTMLResponse)
async def root():
    """Página principal con información y botones de login"""
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>FastAPI + Keycloak Demo</title>
        <style>
            body {{
                font-family: Arial, sans-serif;
                max-width: 800px;
                margin: 50px auto;
                padding: 20px;
                background: #f5f5f5;
            }}
            .container {{
                background: white;
                padding: 30px;
                border-radius: 10px;
                box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            }}
            h1 {{ color: #333; }}
            .button {{
                display: inline-block;
                padding: 10px 20px;
                margin: 10px 5px;
                background: #4CAF50;
                color: white;
                text-decoration: none;
                border-radius: 5px;
                border: none;
                cursor: pointer;
            }}
            .button:hover {{ background: #45a049; }}
            .info {{ 
                background: #e3f2fd;
                padding: 15px;
                border-radius: 5px;
                margin: 20px 0;
            }}
            .endpoint {{
                background: #f9f9f9;
                padding: 10px;
                margin: 10px 0;
                border-left: 3px solid #4CAF50;
            }}
            code {{ 
                background: #333;
                color: #0f0;
                padding: 2px 5px;
                border-radius: 3px;
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🔐 FastAPI + Keycloak Demo</h1>
            
            <div class="info">
                <h3>📋 Información de la Aplicación</h3>
                <p><strong>Keycloak URL:</strong> {KEYCLOAK_URL}</p>
                <p><strong>Realm:</strong> {REALM}</p>
                <p><strong>Client ID:</strong> {CLIENT_ID}</p>
            </div>

            <h3>🚀 Acciones</h3>
            <a href="/login-page" class="button">🔑 Login (Página)</a>
            <a href="{KEYCLOAK_URL}/realms/{REALM}/account" class="button" target="_blank">👤 Mi Cuenta</a>
            <a href="/docs" class="button" target="_blank">📚 API Docs</a>

            <h3>📍 Endpoints Disponibles</h3>
            
            <div class="endpoint">
                <strong>GET /</strong> - Esta página (público)
            </div>
            
            <div class="endpoint">
                <strong>GET /health</strong> - Health check (público)
            </div>
            
            <div class="endpoint">
                <strong>POST /login</strong> - Login con usuario y contraseña (público)
                <br>Body: <code>{{"username": "demo-user", "password": "Demo@User123"}}</code>
            </div>
            
            <div class="endpoint">
                <strong>GET /profile</strong> - Perfil del usuario (🔒 requiere autenticación)
                <br>Header: <code>Authorization: Bearer &lt;token&gt;</code>
            </div>
            
            <div class="endpoint">
                <strong>GET /protected</strong> - Endpoint protegido (🔒 requiere autenticación)
            </div>
            
            <div class="endpoint">
                <strong>GET /admin</strong> - Solo admin (🔒 requiere rol "admin")
            </div>

            <h3>💡 Cómo Usar</h3>
            <ol>
                <li>Haz login para obtener un token</li>
                <li>Copia el <code>access_token</code></li>
                <li>Usa el token en los endpoints protegidos</li>
            </ol>

            <h3>🧪 Probar con cURL</h3>
            <pre style="background: #f0f0f0; padding: 10px; border-radius: 5px; overflow-x: auto;">
# 1. Obtener token
curl -X POST http://localhost:8000/login \\
  -H "Content-Type: application/json" \\
  -d '{{"username": "demo-user", "password": "Demo@User123"}}'

# 2. Usar token en endpoint protegido
curl http://localhost:8000/profile \\
  -H "Authorization: Bearer &lt;TU_TOKEN&gt;"
            </pre>
        </div>
    </body>
    </html>
    """
    return html_content

@app.get("/health")
async def health():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "keycloak_url": KEYCLOAK_URL,
        "realm": REALM
    }

@app.get("/info")
async def info():
    """Información de configuración de Keycloak"""
    try:
        oidc_config = requests.get(OIDC_CONFIG_URL).json()
        return {
            "keycloak_url": KEYCLOAK_URL,
            "realm": REALM,
            "client_id": CLIENT_ID,
            "endpoints": {
                "authorization": oidc_config.get("authorization_endpoint"),
                "token": oidc_config.get("token_endpoint"),
                "userinfo": oidc_config.get("userinfo_endpoint"),
                "logout": oidc_config.get("end_session_endpoint"),
            }
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error obteniendo configuración de Keycloak: {str(e)}"
        )

# ============================================
# ENDPOINTS DE AUTENTICACIÓN
# ============================================

@app.post("/login", response_model=TokenResponse)
async def login(request: LoginRequest):
    """
    Login con usuario y contraseña (Direct Access Grant / Password Flow)
    
    Este endpoint permite obtener un token directamente con usuario y contraseña.
    Útil para testing, pero en producción se recomienda usar Authorization Code Flow.
    
    Usuarios de prueba:
    - username: demo-user, password: Demo@User123 (rol: user)
    - username: admin-user, password: Admin@User123 (roles: admin, user)
    """
    try:
        # Solicitar token a Keycloak
        data = {
            "client_id": CLIENT_ID,
            "grant_type": "password",
            "username": request.username,
            "password": request.password,
            "scope": "openid profile email"
        }
        
        # Si el cliente es confidencial, añadir el secret
        if CLIENT_SECRET:
            data["client_secret"] = CLIENT_SECRET
        
        response = requests.post(TOKEN_URL, data=data)
        
        if response.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Credenciales inválidas"
            )
        
        token_data = response.json()
        
        return TokenResponse(
            access_token=token_data["access_token"],
            refresh_token=token_data.get("refresh_token"),
            token_type=token_data["token_type"],
            expires_in=token_data["expires_in"]
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error durante el login: {str(e)}"
        )

@app.post("/refresh")
async def refresh_token(refresh_token: str):
    """
    Refrescar el access token usando un refresh token
    
    Body: {"refresh_token": "..."}
    """
    try:
        data = {
            "client_id": CLIENT_ID,
            "grant_type": "refresh_token",
            "refresh_token": refresh_token
        }
        
        if CLIENT_SECRET:
            data["client_secret"] = CLIENT_SECRET
        
        response = requests.post(TOKEN_URL, data=data)
        
        if response.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Refresh token inválido"
            )
        
        return response.json()
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error refrescando token: {str(e)}"
        )

@app.get("/login-page", response_class=HTMLResponse)
async def login_page():
    """Página de login simple"""
    html = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Login - FastAPI + Keycloak</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                display: flex;
                justify-content: center;
                align-items: center;
                height: 100vh;
                margin: 0;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            }
            .login-container {
                background: white;
                padding: 40px;
                border-radius: 10px;
                box-shadow: 0 10px 25px rgba(0,0,0,0.2);
                width: 100%;
                max-width: 400px;
            }
            h2 { margin-top: 0; color: #333; text-align: center; }
            input {
                width: 100%;
                padding: 12px;
                margin: 10px 0;
                border: 1px solid #ddd;
                border-radius: 5px;
                box-sizing: border-box;
            }
            button {
                width: 100%;
                padding: 12px;
                background: #4CAF50;
                color: white;
                border: none;
                border-radius: 5px;
                cursor: pointer;
                font-size: 16px;
                margin-top: 10px;
            }
            button:hover { background: #45a049; }
            .result {
                margin-top: 20px;
                padding: 15px;
                border-radius: 5px;
                display: none;
            }
            .success { background: #d4edda; color: #155724; display: block; }
            .error { background: #f8d7da; color: #721c24; display: block; }
            .token-display {
                word-break: break-all;
                font-size: 12px;
                max-height: 200px;
                overflow-y: auto;
                background: #f8f9fa;
                padding: 10px;
                border-radius: 5px;
                margin-top: 10px;
            }
            .hint {
                background: #fff3cd;
                padding: 10px;
                border-radius: 5px;
                margin-bottom: 20px;
                font-size: 14px;
            }
        </style>
    </head>
    <body>
        <div class="login-container">
            <h2>🔐 Login</h2>
            
            <div class="hint">
                <strong>Usuarios de prueba:</strong><br>
                👤 demo-user / Demo@User123<br>
                👤 admin-user / Admin@User123
            </div>
            
            <form id="loginForm">
                <input type="text" id="username" placeholder="Usuario" required>
                <input type="password" id="password" placeholder="Contraseña" required>
                <button type="submit">Iniciar Sesión</button>
            </form>
            
            <div id="result" class="result"></div>
        </div>

        <script>
            document.getElementById('loginForm').addEventListener('submit', async (e) => {
                e.preventDefault();
                
                const username = document.getElementById('username').value;
                const password = document.getElementById('password').value;
                const resultDiv = document.getElementById('result');
                
                try {
                    const response = await fetch('/login', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ username, password })
                    });
                    
                    const data = await response.json();
                    
                    if (response.ok) {
                        resultDiv.className = 'result success';
                        resultDiv.innerHTML = `
                            <strong>✅ Login exitoso!</strong><br><br>
                            <strong>Access Token:</strong>
                            <div class="token-display">${data.access_token}</div>
                            <br>
                            <strong>Expira en:</strong> ${data.expires_in} segundos<br><br>
                            <button onclick="testProfile('${data.access_token}')">
                                🔍 Ver mi perfil
                            </button>
                        `;
                    } else {
                        resultDiv.className = 'result error';
                        resultDiv.innerHTML = `<strong>❌ Error:</strong> ${data.detail}`;
                    }
                } catch (error) {
                    resultDiv.className = 'result error';
                    resultDiv.innerHTML = `<strong>❌ Error:</strong> ${error.message}`;
                }
            });
            
            async function testProfile(token) {
                try {
                    const response = await fetch('/profile', {
                        headers: { 'Authorization': `Bearer ${token}` }
                    });
                    const data = await response.json();
                    alert('Perfil del usuario:\\n\\n' + JSON.stringify(data, null, 2));
                } catch (error) {
                    alert('Error: ' + error.message);
                }
            }
        </script>
    </body>
    </html>
    """
    return html

# ============================================
# ENDPOINTS PROTEGIDOS
# ============================================

@app.get("/profile")
async def get_profile(user: UserInfo = Depends(get_current_user)):
    """
    Obtener perfil del usuario autenticado
    
    Requiere: Token JWT válido en el header Authorization
    """
    return {
        "message": "Perfil del usuario",
        "user": user.dict()
    }

@app.get("/protected")
async def protected_endpoint(user: UserInfo = Depends(get_current_user)):
    """
    Endpoint protegido - solo usuarios autenticados
    """
    return {
        "message": f"¡Hola {user.name or user.username}!",
        "info": "Este es un endpoint protegido",
        "your_roles": user.roles
    }

@app.get("/admin")
async def admin_only(user: UserInfo = Depends(require_role(["admin"]))):
    """
    Endpoint solo para administradores
    
    Requiere: Token JWT con rol "admin"
    """
    return {
        "message": "Área de administración",
        "admin_user": user.username,
        "secret_data": "Datos sensibles solo para admins"
    }

@app.get("/user-or-admin")
async def user_or_admin(user: UserInfo = Depends(require_role(["user", "admin"]))):
    """
    Endpoint para usuarios con rol "user" o "admin"
    """
    return {
        "message": "Acceso concedido",
        "user": user.username,
        "roles": user.roles
    }

# ============================================
# ENDPOINTS DE DATOS (EJEMPLO)
# ============================================

# Base de datos simulada
fake_items_db = [
    {"id": 1, "name": "Laptop", "price": 999.99, "owner": None},
    {"id": 2, "name": "Mouse", "price": 29.99, "owner": None},
    {"id": 3, "name": "Keyboard", "price": 79.99, "owner": None},
]

@app.get("/items")
async def get_items():
    """Listar items (público)"""
    return {"items": fake_items_db}

@app.get("/my-items")
async def get_my_items(user: UserInfo = Depends(get_current_user)):
    """Listar items del usuario autenticado"""
    my_items = [item for item in fake_items_db if item["owner"] == user.username]
    return {
        "user": user.username,
        "items": my_items
    }

@app.post("/items/{item_id}/buy")
async def buy_item(item_id: int, user: UserInfo = Depends(get_current_user)):
    """Comprar un item (solo autenticados)"""
    item = next((item for item in fake_items_db if item["id"] == item_id), None)
    
    if not item:
        raise HTTPException(status_code=404, detail="Item no encontrado")
    
    if item["owner"]:
        raise HTTPException(status_code=400, detail="Item ya comprado")
    
    item["owner"] = user.username
    
    return {
        "message": "Compra exitosa",
        "item": item,
        "buyer": user.username
    }

# ============================================
# INICIAR SERVIDOR
# ============================================

if __name__ == "__main__":
    import uvicorn
    
    print("=" * 60)
    print("🚀 FastAPI + Keycloak Demo")
    print("=" * 60)
    print(f"📍 API: http://localhost:8000")
    print(f"📚 Docs: http://localhost:8000/docs")
    print(f"🔐 Keycloak: {KEYCLOAK_URL}")
    print(f"🌐 Realm: {REALM}")
    print("=" * 60)
    print("\n👤 Usuarios de prueba:")
    print("   - demo-user / Demo@User123 (rol: user)")
    print("   - admin-user / Admin@User123 (roles: admin, user)")
    print("\n💡 Visita http://localhost:8000 para comenzar")
    print("=" * 60)
    
    uvicorn.run(app, host="0.0.0.0", port=8000)
