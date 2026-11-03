-- =============================================================================
-- SCRIPT: maintenance.sql
-- PROYECTO: FoodStore (PostgreSQL 18)
-- MATERIA: Bases de Datos II - Tecnicatura Universitaria en Programación
-- UNIDAD 6: Mantenimiento, respaldo y recuperación
--
-- OBJETIVO: Diagnóstico previo, justificación técnica y ejecución de mantenimiento
--           seguro sin bloqueo de tablas ni degradación del servicio productivo.
-- =============================================================================

/*
================================================================================
JUSTIFICACIÓN TÉCNICA: PROHIBICIÓN DE 'VACUUM FULL' COMO RUTINA PERIÓDICA
================================================================================
El comando VACUUM FULL NO debe utilizarse como tarea de mantenimiento rutinario
por los siguientes fundamentos técnicos de arquitectura PostgreSQL:

1. BLOQUEO EXCLUSIVO TOTAL (AccessExclusiveLock):
   VACUUM FULL solicita un bloqueo de tabla de máximo nivel. Esto impide no solo 
   las escrituras (INSERT, UPDATE, DELETE), sino también cualquier LECTURA (SELECT).
   En un entorno de producción como FoodStore, ejecutarlo durante la operación 
   provoca la congelación de las sesiones de los usuarios, timeouts en la capa de 
   aplicación y una denegación de servicio no planificada (downtime).

2. CONSUMO DE ESPACIO EN DISCO (Duplicación temporal de tablas):
   A diferencia del VACUUM estándar (que limpia tuplas muertas in-situ y marca 
   el espacio en el FSM - Free Space Map para reusarlo), VACUUM FULL crea un 
   archivo físico nuevo en disco y copia las tuplas vivas. Si la tabla ocupa 
   10 GB, se requieren al menos 10 GB adicionales libres en el disco. Si el 
   volumen se queda sin almacenamiento, la transacción aborta con riesgo operativo.

3. SATURACIÓN SEVERA DE I/O:
   Reescribir físicamente cada registro e índice genera una saturación extrema 
   de lectura/escritura en disco y desaloja el cache de memoria compartida 
   (shared_buffers), degradando severamente el rendimiento general del cluster.

4. ESTRATEGIA PROFESIONAL APLICADA:
   - Uso de VACUUM estándar (concurrente): No bloquea lecturas ni escrituras.
   - Uso de ANALYZE: Actualiza las estadísticas del catálogo (pg_statistic) 
     para que el optimizador de consultas (Cost-Based Query Planner) elija 
     planes de ejecución óptimos (Index Scans vs Seq Scans).
   - Afinar los parámetros del demonio autovacuum para que trabaje continuamente 
     de fondo en baja prioridad.
================================================================================
*/


-- -----------------------------------------------------------------------------
-- PASO 1: DIAGNÓSTICO PREVIO DE ESTADO Y CANDIDATAS A MANTENIMIENTO
-- Examina el porcentaje de tuplas muertas (dead tuples) y el historial de ejecución.
-- Si pct_tuplas_muertas > 15% o si last_autoanalyze es NULL o muy antiguo,
-- la tabla califica técnicamente para mantenimiento manual asistido.
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
    CASE 
        WHEN n_dead_tup > 1000 OR (n_dead_tup::NUMERIC / NULLIF(n_live_tup + n_dead_tup, 0) > 0.15)
            THEN 'REQUIERE VACUUM MANUAL (Acumulación de bloat)'
        WHEN last_autoanalyze IS NULL AND last_analyze IS NULL
            THEN 'REQUIERE ANALYZE (Sin estadísticas registradas)'
        ELSE 'SALUDABLE (Dentro de umbrales normales de autovacuum)'
    END AS estado_diagnostico,
    last_autovacuum,
    last_autoanalyze,
    last_vacuum,
    last_analyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;


-- -----------------------------------------------------------------------------
-- PASO 2: ACCIÓN DE MANTENIMIENTO SEGURA Y JUSTIFICADA (NO BLOQUEANTE)
--
-- Justificación:
-- - Se ejecuta VACUUM (VERBOSE, ANALYZE) sobre las tablas maestras y
--   transaccionales de FoodStore según el esquema real ('usuario', 'usuario_anon',
--   'categoria', 'producto', 'pedido' y 'detalle_pedido').
-- - VERBOSE: Proporciona telemetría detallada del espacio reutilizable recuperado.
-- - ANALYZE: Recalcula histogramas y frecuencias de valores para el planificador.
-- - Bloqueo adquirido: ShareUpdateExclusiveLock (permite SELECT, INSERT, UPDATE, DELETE).
-- -----------------------------------------------------------------------------

-- Mantenimiento preventivo en tablas maestras y transaccionales
VACUUM (VERBOSE, ANALYZE) categoria;
VACUUM (VERBOSE, ANALYZE) producto;
VACUUM (VERBOSE, ANALYZE) usuario;
VACUUM (VERBOSE, ANALYZE) usuario_anon;
VACUUM (VERBOSE, ANALYZE) pedido;
VACUUM (VERBOSE, ANALYZE) detalle_pedido;


-- -----------------------------------------------------------------------------
-- PASO 3: VERIFICACIÓN POST-MANTENIMIENTO
-- Confirma la reducción de tuplas muertas a cero o valores mínimos y actualiza
-- la marca temporal de last_vacuum y last_analyze.
-- -----------------------------------------------------------------------------
SELECT 
    relname AS tabla,
    n_live_tup AS tuplas_vivas,
    n_dead_tup AS tuplas_muertas_restantes,
    last_vacuum AS fecha_vacuum_manual,
    last_analyze AS fecha_analyze_manual
FROM pg_stat_user_tables
WHERE relname IN ('categoria', 'producto', 'usuario', 'usuario_anon', 'pedido', 'detalle_pedido')
ORDER BY relname;
