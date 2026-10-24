-- roles.sql - Parte A TP Unidad 5
-- Esquema de roles y permisos con principio de mínimo privilegio

-- Limpiar roles existentes si es necesario (solo para desarrollo)
-- DROP ROLE IF EXISTS rol_app_lectura;
-- DROP ROLE IF EXISTS rol_app_escritura;
-- DROP ROLE IF EXISTS rol_soporte;
-- DROP ROLE IF EXISTS rol_reportes;
-- DROP ROLE IF EXISTS app_web;
-- DROP ROLE IF EXISTS admin_datos;
-- DROP ROLE IF EXISTS rol_auditoria;

-- 1. CREACIÓN DE ROLES DE GRUPO
CREATE ROLE rol_app_lectura NOLOGIN;
CREATE ROLE rol_app_escritura NOLOGIN;
CREATE ROLE rol_soporte NOLOGIN;
CREATE ROLE rol_reportes NOLOGIN;
CREATE ROLE rol_auditoria NOLOGIN;

-- 2. CREACIÓN DE ROLES DE LOGIN
CREATE ROLE app_web WITH LOGIN PASSWORD 'web_pass_dev';
CREATE ROLE admin_datos WITH LOGIN PASSWORD 'admin_pass_dev';

-- 3. ASIGNACIÓN DE ROLES
GRANT rol_app_lectura TO app_web;
GRANT rol_app_escritura TO app_web;
GRANT rol_reportes TO app_web;

-- Admin datos tiene privilegios elevados controlados
GRANT rol_app_lectura TO admin_datos;
GRANT rol_app_escritura TO admin_datos;
GRANT rol_soporte TO admin_datos;
GRANT rol_reportes TO admin_datos;
GRANT rol_auditoria TO admin_datos;

-- 4. PRIVILEGIOS A NIVEL DE TABLA - PRINCIPIO DE MÍNIMO PRIVILEGIO

-- rol_app_lectura: Solo lectura
GRANT USAGE ON SCHEMA public TO rol_app_lectura;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_app_lectura;

-- rol_app_escritura: Lectura y escritura en tablas operativas
GRANT USAGE ON SCHEMA public TO rol_app_escritura;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO rol_app_escritura;
-- NOTA: Sin DELETE masivo por defecto - se otorgará específicamente si es necesario

-- rol_soporte: Privilegios limitados para soporte
GRANT USAGE ON SCHEMA public TO rol_soporte;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_soporte;

-- rol_reportes: Solo lectura para reportes
GRANT USAGE ON SCHEMA public TO rol_reportes;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_reportes;

-- rol_auditoria: Acceso para auditoría
GRANT USAGE ON SCHEMA public TO rol_auditoria;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_auditoria;

-- 5. PERMISO A NIVEL DE COLUMNA (caso específico)
-- Otorgar acceso solo a columnas no sensibles o columnas específicas de usuario
-- Ejemplo: permitir ver solo id_usuario, nombre, apellido (sin contraseña, sin datos sensibles)
GRANT USAGE ON SCHEMA public TO rol_app_lectura;
-- Revocar SELECT completo sobre tabla usuario y otorgar por columnas
REVOKE SELECT ON TABLE usuario FROM rol_app_lectura;
GRANT SELECT (id_usuario, nombre_usuario, email, fecha_registro) ON TABLE usuario TO rol_app_lectura;

-- 6. ALTER DEFAULT PRIVILEGES PARA TABLAS FUTURAS
-- Asegurar que las tablas futuras hereden la misma política de mínimo privilegio
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE ON SCHEMAS TO rol_app_lectura;
    
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO rol_app_lectura;
    
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE ON TABLES TO rol_app_escritura;
    
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO rol_soporte;
    
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO rol_reportes;
    
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO rol_auditoria;

-- 7. SECUENCIAS (si existen)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO rol_app_escritura;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO rol_app_escritura;

-- 8. FUNCIONES (mantener coherencia con fn_autenticar y fn_resetear_password)
GRANT EXECUTE ON FUNCTION fn_autenticar(text, text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION fn_resetear_password(text, text) TO PUBLIC;
