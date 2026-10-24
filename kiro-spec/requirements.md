# requirements.md

## Objetivo
Diseñar e implementar un esquema de roles y permisos para la base de datos Food Store, aplicando el principio de mínimo privilegio.

## Roles identificados

### Roles de grupo (roles que agrupan privilegios)
1. **rol_app_lectura** - Rol para lectura de datos de aplicación
2. **rol_app_escritura** - Rol para lectura y escritura de datos operativos
3. **rol_soporte** - Rol para operaciones de soporte con restricciones
4. **rol_reportes** - Rol para generación de reportes (solo lectura agregada)

### Roles de login (usuarios que se conectan)
1. **app_web** - Usuario de la aplicación web
2. **admin_datos** - Administrador de datos

### Roles adicionales considerados
- **rol_auditoria** (adicional) - Para funciones de auditoría con acceso a logs
  - Justificación: Necesario para operaciones de auditoría separadas de la administración

## Requisitos por rol
Cada rol debe tener solo los privilegios estrictamente necesarios para cumplir su función.
