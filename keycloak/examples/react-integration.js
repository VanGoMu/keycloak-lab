// Ejemplo de integración de Keycloak con React
// npm install keycloak-js

import Keycloak from 'keycloak-js';
import { createContext, useContext, useState, useEffect } from 'react';

// Configuración de Keycloak
const keycloakConfig = {
  url: 'http://localhost:8080',
  realm: 'demo-app',
  clientId: 'demo-app-frontend',
};

// Crear instancia de Keycloak
const keycloak = new Keycloak(keycloakConfig);

// Context para compartir la instancia de Keycloak
const KeycloakContext = createContext(null);

// Provider component
export const KeycloakProvider = ({ children }) => {
  const [authenticated, setAuthenticated] = useState(false);
  const [keycloakInstance, setKeycloakInstance] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Inicializar Keycloak
    keycloak
      .init({
        onLoad: 'login-required', // o 'check-sso' para login opcional
        checkLoginIframe: true,
        pkceMethod: 'S256', // Usar PKCE para seguridad
      })
      .then((authenticated) => {
        setAuthenticated(authenticated);
        setKeycloakInstance(keycloak);
        setLoading(false);

        // Configurar refresh token automático
        setInterval(() => {
          keycloak
            .updateToken(70)
            .then((refreshed) => {
              if (refreshed) {
                console.log('Token refreshed');
              }
            })
            .catch(() => {
              console.error('Failed to refresh token');
            });
        }, 60000); // Cada 60 segundos
      })
      .catch((error) => {
        console.error('Keycloak initialization failed', error);
        setLoading(false);
      });
  }, []);

  if (loading) {
    return <div>Cargando autenticación...</div>;
  }

  return (
    <KeycloakContext.Provider value={{ keycloak: keycloakInstance, authenticated }}>
      {children}
    </KeycloakContext.Provider>
  );
};

// Hook personalizado para usar Keycloak
export const useKeycloak = () => {
  const context = useContext(KeycloakContext);
  if (!context) {
    throw new Error('useKeycloak must be used within KeycloakProvider');
  }
  return context;
};

// Componente de ejemplo que usa autenticación
export const UserProfile = () => {
  const { keycloak, authenticated } = useKeycloak();

  if (!authenticated) {
    return <div>No autenticado</div>;
  }

  const userInfo = keycloak.tokenParsed;

  return (
    <div>
      <h2>Perfil de Usuario</h2>
      <p><strong>Username:</strong> {userInfo.preferred_username}</p>
      <p><strong>Email:</strong> {userInfo.email}</p>
      <p><strong>Nombre:</strong> {userInfo.given_name} {userInfo.family_name}</p>
      <p><strong>Roles:</strong> {userInfo.realm_access?.roles.join(', ')}</p>
      
      <button onClick={() => keycloak.logout()}>
        Cerrar Sesión
      </button>
    </div>
  );
};

// Componente protegido que requiere un rol específico
export const AdminPanel = () => {
  const { keycloak, authenticated } = useKeycloak();

  if (!authenticated) {
    return <div>Debes iniciar sesión</div>;
  }

  const hasAdminRole = keycloak.hasRealmRole('admin');

  if (!hasAdminRole) {
    return <div>No tienes permisos de administrador</div>;
  }

  return (
    <div>
      <h2>Panel de Administración</h2>
      <p>Solo visible para administradores</p>
    </div>
  );
};

// HOC para proteger rutas
export const withAuth = (Component, requiredRoles = []) => {
  return (props) => {
    const { keycloak, authenticated } = useKeycloak();

    if (!authenticated) {
      return <div>Acceso denegado. Por favor inicia sesión.</div>;
    }

    if (requiredRoles.length > 0) {
      const hasRequiredRole = requiredRoles.some(role => 
        keycloak.hasRealmRole(role)
      );

      if (!hasRequiredRole) {
        return <div>No tienes los permisos necesarios.</div>;
      }
    }

    return <Component {...props} />;
  };
};

// Uso en App.js
export const App = () => {
  return (
    <KeycloakProvider>
      <div className="App">
        <h1>Mi Aplicación con Keycloak</h1>
        <UserProfile />
        <AdminPanel />
      </div>
    </KeycloakProvider>
  );
};

// Hacer peticiones HTTP con token
export const apiClient = {
  get: async (url) => {
    const token = keycloak.token;
    const response = await fetch(url, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    });
    return response.json();
  },
  
  post: async (url, data) => {
    const token = keycloak.token;
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(data),
    });
    return response.json();
  },
};
