-- Verificación de roles y permisos
\echo '=== ROLES Y ATRIBUTOS ==='
\du

\echo ''
\echo '=== PRIVILEGIOS POR ROL EN TABLAS ==='
SELECT grantee, table_schema, table_name, privilege_type, is_grantable
FROM information_schema.role_table_grants
WHERE grantee IN ('rol_app_lectura', 'rol_app_escritura', 'rol_soporte', 'rol_reportes', 'rol_auditoria', 'app_web', 'admin_datos')
ORDER BY grantee, table_schema, table_name, privilege_type;
