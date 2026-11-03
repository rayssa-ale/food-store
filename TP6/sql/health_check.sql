-- =============================================================================
-- SCRIPT: health_check.sql
-- PROYECTO: FoodStore (PostgreSQL 18)
-- MATERIA: Bases de Datos II - Tecnicatura Universitaria en Programación
-- UNIDAD 6: Mantenimiento, respaldo y recuperación
--
-- OBJETIVO: Monitoreo preventivo y auditoría de salud operativa.
-- NOTA: Utiliza current_database() para garantizar compatibilidad con 'foodStore'
--       y entornos de prueba sin riesgos de diferencias entre mayúsculas y minúsculas.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- CONTROL 1: Tamaño actual de la base de datos
-- Evalúa el consumo físico en disco del catálogo y los archivos relacionales.
-- -----------------------------------------------------------------------------
SELECT 
    current_database() AS base_de_datos,
    pg_database_size(current_database()) AS tamano_bytes,
    pg_size_pretty(pg_database_size(current_database())) AS tamano_legible;


-- -----------------------------------------------------------------------------
-- CONTROL 2: Actividad de conexiones y balance transaccional
-- - numbackends: Número de conexiones cliente concurrentes.
-- - xact_commit: Cantidad acumulada de transacciones exitosas.
-- - xact_rollback: Cantidad acumulada de transacciones abortadas/revertidas.
-- - tasa_exito_pct: Porcentaje de éxito transaccional (esperado > 95%).
-- -----------------------------------------------------------------------------
SELECT 
    datname AS base_de_datos,
    numbackends AS conexiones_activas,
    xact_commit AS transacciones_confirmadas,
    xact_rollback AS transacciones_abortadas,
    ROUND(
        (xact_commit::NUMERIC / NULLIF(xact_commit + xact_rollback, 0)::NUMERIC) * 100, 
        2
    ) AS tasa_exito_pct
FROM pg_stat_database
WHERE datname = current_database();


-- -----------------------------------------------------------------------------
-- CONTROL 3: Estado de tablas, tuplas muertas y actividad de Autovacuum
-- Monitorea la acumulación de basura (bloat) generada por UPDATEs y DELETEs,
-- y registra cuándo intervino por última vez el demonio de autovacuum/autoanalyze.
-- -----------------------------------------------------------------------------
SELECT 
    schemaname AS esquema,
    relname AS tabla,
    n_live_tup AS tuplas_vivas,
    n_dead_tup AS tuplas_muertas,
    ROUND(
        (n_dead_tup::NUMERIC / NULLIF(n_live_tup + n_dead_tup, 0)::NUMERIC) * 100, 
        2
    ) AS pct_tuplas_muertas,
    last_autovacuum AS ultimo_autovacuum,
    last_autoanalyze AS ultimo_autoanalyze,
    last_vacuum AS ultimo_vacuum_manual,
    last_analyze AS ultimo_analyze_manual
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC, pct_tuplas_muertas DESC NULLS LAST;


-- -----------------------------------------------------------------------------
-- CONTROL 4: Consultas activas en ejecución y transacciones no ociosas
-- Detecta consultas lentas, bloqueos potenciales o sesiones 'idle in transaction'
-- que retienen cerraduras e impiden que autovacuum limpie tuplas muertas.
-- -----------------------------------------------------------------------------
SELECT 
    pid AS id_proceso,
    usename AS usuario,
    client_addr AS ip_cliente,
    application_name AS aplicacion,
    state AS estado,
    NOW() - query_start AS duracion_consulta,
    NOW() - xact_start AS duracion_transaccion,
    query AS consulta_sql
FROM pg_stat_activity
WHERE datname = current_database()
  AND state <> 'idle'
  AND pid <> pg_backend_pid() -- Excluye la propia consulta de monitoreo
ORDER BY duracion_consulta DESC NULLS LAST;
