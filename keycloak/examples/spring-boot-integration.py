# Ejemplo de integración de Keycloak con Spring Boot
# Añadir a pom.xml o build.gradle

# pom.xml (Maven)
"""
<dependencies>
    <!-- Spring Boot Starter Web -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    
    <!-- Spring Boot Starter OAuth2 Resource Server -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-oauth2-resource-server</artifactId>
    </dependency>
    
    <!-- Spring Boot Starter OAuth2 Client (para login) -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-oauth2-client</artifactId>
    </dependency>
    
    <!-- Spring Security -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-security</artifactId>
    </dependency>
</dependencies>
"""

# application.yml
"""
spring:
  security:
    oauth2:
      client:
        registration:
          keycloak:
            client-id: demo-app-backend
            client-secret: demo-app-backend-secret-change-me
            scope: openid,profile,email
            authorization-grant-type: authorization_code
            redirect-uri: "{baseUrl}/login/oauth2/code/{registrationId}"
        provider:
          keycloak:
            issuer-uri: http://localhost:8080/realms/demo-app
            user-name-attribute: preferred_username
      
      resourceserver:
        jwt:
          issuer-uri: http://localhost:8080/realms/demo-app
          jwk-set-uri: http://localhost:8080/realms/demo-app/protocol/openid-connect/certs

server:
  port: 8000
"""

# SecurityConfig.java
"""
package com.example.demo.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import java.util.Arrays;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity(prePostEnabled = true)
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .cors().and()
            .csrf().disable()
            .authorizeHttpRequests(authz -> authz
                .requestMatchers("/api/public/**").permitAll()
                .requestMatchers("/api/admin/**").hasRole("admin")
                .requestMatchers("/api/user/**").hasAnyRole("user", "admin")
                .anyRequest().authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt
                    .jwtAuthenticationConverter(jwtAuthenticationConverter())
                )
            )
            .sessionManagement()
                .sessionCreationPolicy(SessionCreationPolicy.STATELESS);

        return http.build();
    }

    @Bean
    public JwtAuthenticationConverter jwtAuthenticationConverter() {
        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(jwt -> {
            // Extraer roles de Keycloak
            Map<String, Object> realmAccess = jwt.getClaim("realm_access");
            
            if (realmAccess == null || realmAccess.get("roles") == null) {
                return List.of();
            }

            @SuppressWarnings("unchecked")
            List<String> roles = (List<String>) realmAccess.get("roles");

            return roles.stream()
                .map(role -> new SimpleGrantedAuthority("ROLE_" + role))
                .collect(Collectors.toList());
        });

        return converter;
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();
        configuration.setAllowedOrigins(Arrays.asList("http://localhost:3000"));
        configuration.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        configuration.setAllowedHeaders(Arrays.asList("*"));
        configuration.setAllowCredentials(true);
        
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }
}
"""

# UserController.java
"""
package com.example.demo.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api")
public class UserController {

    @GetMapping("/public/hello")
    public String publicEndpoint() {
        return "Este endpoint es público";
    }

    @GetMapping("/user/profile")
    @PreAuthorize("hasAnyRole('user', 'admin')")
    public Map<String, Object> getUserProfile(Authentication authentication) {
        Jwt jwt = (Jwt) authentication.getPrincipal();
        
        return Map.of(
            "username", jwt.getClaim("preferred_username"),
            "email", jwt.getClaim("email"),
            "name", jwt.getClaim("name"),
            "roles", jwt.getClaim("realm_access")
        );
    }

    @GetMapping("/admin/users")
    @PreAuthorize("hasRole('admin')")
    public String getAdminData() {
        return "Datos de administración - Solo admin puede ver esto";
    }

    @PostMapping("/user/data")
    @PreAuthorize("hasRole('user')")
    public String createUserData(@RequestBody Map<String, Object> data, 
                                  Authentication authentication) {
        Jwt jwt = (Jwt) authentication.getPrincipal();
        String username = jwt.getClaim("preferred_username");
        
        return "Datos creados por: " + username;
    }
}
"""

# Application.java
"""
package com.example.demo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
"""

# Ejemplo de cliente HTTP para consumir la API con token
"""
// Desde un cliente (ej. React), obtener token y hacer petición:

const token = keycloak.token;

fetch('http://localhost:8000/api/user/profile', {
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  }
})
.then(response => response.json())
.then(data => console.log(data));
"""

# Para testing con curl:
"""
# 1. Obtener token desde Keycloak
curl -X POST 'http://localhost:8080/realms/demo-app/protocol/openid-connect/token' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'client_id=demo-app-backend' \
  -d 'client_secret=demo-app-backend-secret-change-me' \
  -d 'grant_type=password' \
  -d 'username=demo-user' \
  -d 'password=demo123' \
  -d 'scope=openid'

# 2. Usar el access_token en las peticiones
curl -X GET 'http://localhost:8000/api/user/profile' \
  -H 'Authorization: Bearer <ACCESS_TOKEN>'
"""
