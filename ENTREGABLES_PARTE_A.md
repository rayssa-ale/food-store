# Entregables Parte A - TP Unidad 5

## Archivos generados:
1. **roles.sql** - Script con CREATE ROLE, GRANT/REVOKE, permiso a nivel de columna, ALTER DEFAULT PRIVILEGES
2. **kiro-spec/requirements.md** - Especificación de requisitos generada con Kiro
3. **kiro-spec/design.md** - Diseño de roles y permisos generado con Kiro
4. **kiro-spec/auditoria_opencode.md** - Registro de auditoría con OpenCode
5. **scripts/verificacion.sql** - Script de verificación
6. **verificacion/verificacion_permisos.txt** - Archivo para salida de verificación
7. **BITACORA.md** - Bitácora actualizada con registro de IA

## Cumplimiento de requisitos:
- [x] Especificación en Kiro (requirements + design)
- [x] CREATE ROLE para todos los roles (grupos + logins)
- [x] GRANT/REVOKE coherentes con especificación
- [x] Al menos un caso de permiso a nivel de columna (tabla usuario)
- [x] SENTENCIA ALTER DEFAULT PRIVILEGES
- [x] Verificación con \du y information_schema.role_table_grants
- [x] Auditoría con OpenCode registrada
- [x] Caso documentado donde OpenCode propuso permiso más amplio y fue rechazado
