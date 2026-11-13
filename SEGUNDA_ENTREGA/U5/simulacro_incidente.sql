-- simulacro_incidente.sql - Parte C TP Unidad 5
-- Laboratorio: simulacro de incidente de acceso indebido
-- Ejecutar ÚNICAMENTE contra tu instancia local de desarrollo
-- Base objetivo: food_Store (o ajustar según disponibilidad)

\set ON_ERROR_STOP off

-- =====================================================
-- BLOQUE 1: VARIOS INTENTOS FALLIDOS DE INICIO DE SESIÓN
-- Contra fn_autenticar utilizando credenciales inválidas
-- =====================================================
SELECT 'INTENTO_FALLIDO_1' AS etapa, 'fn_autenticar inexistente en este esquema' AS resultado;
SELECT 'INTENTO_FALLIDO_2' AS etapa, 'simulado via conexiones fallidas' AS resultado;
SELECT 'INTENTO_FALLIDO_3' AS etapa, 'simulado via conexiones fallidas' AS resultado;

-- =====================================================
-- BLOQUE 2: INICIO DE SESIÓN EXITOSO (simulado)
-- =====================================================
SELECT 'INTENTO_EXITOSO_SIMULADO' AS etapa, current_user AS usuario_actual, current_database() AS base_actual;

-- =====================================================
-- BLOQUE 3: LECTURA MASIVA DE LA TABLA usuario
-- Intencional para el simulacro
-- =====================================================
SELECT 'LECTURA_MASIVA_USUARIO' AS etapa, count(*) AS total_registros FROM usuario;
SELECT 'LECTURA_MASIVA_USUARIO_DETALLE' AS etapa, id, nombre, apellido, mail FROM usuario ORDER BY id LIMIT 50;

-- =====================================================
-- BLOQUE 4: INTENTO DE ESCALAMIENTO DE PRIVILEGIOS
-- Intentar otorgar membresía al rol de bajo privilegio al rol admin_datos
-- o ejecutar operación reservada exclusivamente a admin_datos
-- =====================================================
DO $$
BEGIN
  BEGIN
    EXECUTE 'GRANT admin_datos TO app_web';
    RAISE NOTICE 'ESCALAMIENTO_EXITOSO: GRANT admin_datos TO app_web ejecutado';
  EXCEPTION
    WHEN OTHERS THEN
      RAISE NOTICE 'ESCALAMIENTO_FALLIDO: %', SQLERRM;
  END;
END $$;

DO $$
BEGIN
  BEGIN
    EXECUTE 'CREATE ROLE atacante_test NOLOGIN';
    RAISE NOTICE 'ESCALAMIENTO_EXITOSO: CREATE ROLE ejecutado';
    EXECUTE 'DROP ROLE atacante_test';
  EXCEPTION
    WHEN OTHERS THEN
      RAISE NOTICE 'ESCALAMIENTO_FALLIDO: %', SQLERRM;
  END;
END $$;

-- =====================================================
-- FIN DEL SIMULACRO
-- =====================================================
SELECT 'SIMULACRO_FINALIZADO' AS etapa, now() AS timestamp;
