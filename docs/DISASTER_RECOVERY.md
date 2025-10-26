# Disaster Recovery - Keycloak

Sistema completo de backup, restore y disaster recovery para Keycloak en producción.

## 📁 Estructura de Scripts

```
scripts/prod/
├── disaster_recovery.sh  # 🎯 Script principal con menú interactivo
├── backup.sh            # Script de backup
└── restore.sh           # Script de restore
```

## 🚀 Inicio Rápido

### Ejecutar el menú de Disaster Recovery

```bash
cd /home/epicuro/repo/keycloak-lab
bash scripts/prod/disaster_recovery.sh
```

## 📋 Funcionalidades del Menú

### 1️⃣ Ver Estado del Sistema
- Detecta automáticamente el entorno (prod/dev)
- Muestra estado de contenedores Keycloak y PostgreSQL
- Información de espacio en disco
- Detalles del último backup

### 2️⃣ Listar Backups Disponibles
- Lista todos los backups con timestamp
- Muestra tamaño de cada backup
- Indica si incluye backups de realms
- Ordenados por fecha (más reciente primero)

### 3️⃣ Crear Nuevo Backup
- Backup completo de PostgreSQL (comprimido con gzip)
- Exportación de realms vía API REST
- Genera archivo de metadatos
- Detección automática de entorno

**Qué incluye:**
- Base de datos PostgreSQL completa
- Configuración de realms (excepto master)
- Información del sistema y versiones
- Timestamp para identificación única

### 4️⃣ Restaurar desde Backup
- Selección interactiva de backup
- Confirmación antes de sobrescribir
- Detiene Keycloak automáticamente
- Cierra conexiones activas a PostgreSQL
- Restaura base de datos completa
- Reinicia Keycloak
- Verifica disponibilidad

**Proceso:**
1. Detener Keycloak
2. Cerrar conexiones PostgreSQL
3. Eliminar y recrear base de datos
4. Restaurar datos
5. Copiar realms
6. Reiniciar servicios
7. Verificar disponibilidad

### 5️⃣ Verificar Integridad de Backups
- Valida archivos gzip
- Verifica que no estén corruptos
- Comprueba existencia de archivos de realms
- Genera reporte de validación

### 6️⃣ Prueba de Disaster Recovery
- Prueba automatizada del proceso completo
- Crea backup de seguridad
- Realiza modificación de prueba
- Restaura desde backup
- Verifica éxito de la restauración

**Pasos de la prueba:**
1. Backup automático
2. Modificación del displayName del realm
3. Restore completo
4. Verificación de que los datos volvieron al estado original

### 7️⃣ Limpiar Backups Antiguos
- Elimina backups con más de X días
- Pregunta número de días a conservar
- Muestra backups a eliminar antes de confirmar
- Limpia archivos y directorios relacionados

## 🔧 Uso de Scripts Individuales

### Crear Backup Manualmente

```bash
bash scripts/prod/backup.sh
```

**Archivos generados:**
```
backups/
├── keycloak_db_YYYYMMDD_HHMMSS.sql.gz    # Base de datos
├── realms_YYYYMMDD_HHMMSS/                # Realms exportados
│   └── demo-app-realm.json
└── info_YYYYMMDD_HHMMSS.txt               # Metadatos
```

### Restaurar Backup Manualmente

```bash
# Ver backups disponibles
ls -1 backups/*.sql.gz | sed 's/.*keycloak_db_//' | sed 's/.sql.gz//'

# Restaurar (reemplaza TIMESTAMP con el valor real)
bash scripts/prod/restore.sh YYYYMMDD_HHMMSS
```

**Ejemplo:**
```bash
bash scripts/prod/restore.sh 20251026_101408
```

## ⚙️ Configuración

### Variables de Entorno

Los scripts detectan automáticamente el entorno:
- `keycloak-prod` (producción con HTTPS)
- `keycloak-dev` (desarrollo con HTTP)

### Credenciales por Defecto

**Admin Keycloak:**
- Usuario: Ver `KC_ADMIN_USERNAME` en `docker/.env`
- Password: Ver `KC_ADMIN_PASSWORD` en `docker/.env`

**PostgreSQL:**
- Usuario: `keycloak`
- Base de datos: `keycloak`
- Password: Ver `POSTGRES_PASSWORD` en `docker/.env`

**Usuarios Demo:**
- demo-user: Ver `DEMO_USER_PASSWORD` en `docker/.env`
- admin-user: Ver `ADMIN_USER_PASSWORD` en `docker/.env`

## 📊 Retención de Backups

Por defecto, el script `backup.sh` limpia automáticamente backups con más de **7 días**.

Puedes cambiar esto editando la línea en `backup.sh`:
```bash
find "$BACKUP_DIR" -type f -name "*.sql.gz" -mtime +7 -delete
```

O usar la opción 7 del menú para limpieza manual con días personalizados.

## 🎯 Casos de Uso

### 1. Backup Antes de Actualización

```bash
# Crear backup
bash scripts/prod/backup.sh

# Realizar actualización de Keycloak
# ...

# Si algo sale mal, restaurar
bash scripts/prod/restore.sh TIMESTAMP
```

### 2. Disaster Recovery Completo

```bash
# En caso de pérdida total de datos
bash scripts/prod/disaster_recovery.sh
# Seleccionar opción 4: Restaurar desde backup
```

### 3. Migración a Nuevo Servidor

```bash
# En servidor origen
bash scripts/prod/backup.sh

# Copiar backups/ a nuevo servidor
scp -r backups/ usuario@nuevo-servidor:/path/to/keycloak-lab/

# En servidor destino
bash scripts/prod/restore.sh TIMESTAMP
```

### 4. Prueba Periódica de Backups

```bash
# Ejecutar prueba automatizada cada mes
bash scripts/prod/disaster_recovery.sh
# Seleccionar opción 6: Prueba de disaster recovery
```

## ✅ Verificación Post-Restore

Después de una restauración, verifica:

1. **Keycloak Admin Console**
   ```bash
   # Cargar credenciales desde .env
   source docker/.env
   
   # URL: https://localhost:8443/admin
   # Usuario: ${KC_ADMIN_USERNAME}
   # Password: ${KC_ADMIN_PASSWORD}
   ```

2. **Autenticación de Usuarios**
   ```bash
   # Cargar credenciales desde .env
   source docker/.env
   
   curl -k -s "https://localhost:8443/realms/demo-app/protocol/openid-connect/token" \
     -H "Content-Type: application/x-www-form-urlencoded" \
     -d "username=demo-user" \
     -d "password=${DEMO_USER_PASSWORD}" \
     -d "grant_type=password" \
     -d "client_id=demo-app-frontend"
   ```

3. **Logs de Keycloak**
   ```bash
   docker logs -f keycloak-prod
   ```

## 🔒 Seguridad

### Consideraciones Importantes

1. **Los backups contienen datos sensibles:**
   - Contraseñas hasheadas
   - Configuración de clientes
   - Secretos de aplicaciones

2. **Recomendaciones:**
   - Almacenar backups en ubicación segura
   - Encriptar backups para almacenamiento a largo plazo
   - Limitar acceso al directorio `backups/`
   - No versionar backups en Git

3. **Permisos:**
   ```bash
   chmod 700 backups/
   chmod 600 backups/*.sql.gz
   ```

## 🐛 Troubleshooting

### Error: "database is being accessed by other users"

**Solución:** El script ahora cierra automáticamente las conexiones activas. Si persiste:
```bash
docker restart keycloak-prod
# Esperar 5 segundos
bash scripts/prod/restore.sh TIMESTAMP
```

### Error: "No se encuentra el contenedor"

**Solución:** Verifica que Keycloak esté corriendo:
```bash
docker ps | grep keycloak
```

### Backup corrupto

**Solución:** Usa la opción 5 del menú para verificar integridad:
```bash
bash scripts/prod/disaster_recovery.sh
# Seleccionar opción 5
```

## 📈 Mejores Prácticas

1. **Backups Regulares**
   - Crear backup antes de cada cambio importante
   - Backup automático diario (usar cron)

2. **Pruebas de Restore**
   - Probar proceso de restore mensualmente
   - Usar la opción 6 del menú (prueba automatizada)

3. **Monitoreo**
   - Verificar espacio en disco regularmente
   - Revisar logs de backups

4. **Documentación**
   - Documentar procedimientos específicos de tu entorno
   - Mantener lista de backups críticos

## 🔄 Automatización con Cron

### Backup Diario (2:00 AM)

```bash
# Editar crontab
crontab -e

# Agregar línea
0 2 * * * cd /home/epicuro/repo/keycloak-lab && bash scripts/prod/backup.sh >> /var/log/keycloak-backup.log 2>&1
```

### Limpieza Semanal (Domingos 3:00 AM)

```bash
0 3 * * 0 find /home/epicuro/repo/keycloak-lab/backups -type f -name "*.sql.gz" -mtime +30 -delete
```

## 📞 Soporte

Para problemas o mejoras, revisar:
- Logs de backup: `backups/info_TIMESTAMP.txt`
- Logs de Docker: `docker logs keycloak-prod`
- Logs de PostgreSQL: `docker logs keycloak-postgres`

## 📝 Changelog

### v1.0.0 - 2025-10-26
- ✅ Script de disaster recovery con menú interactivo
- ✅ Backup automático de PostgreSQL y realms
- ✅ Restore con cierre de conexiones automático
- ✅ Verificación de integridad de backups
- ✅ Prueba automatizada de disaster recovery
- ✅ Limpieza de backups antiguos
- ✅ Detección automática de entorno (prod/dev)
- ✅ Exportación de realms vía API REST
