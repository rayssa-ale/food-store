-- ============================================================
-- FOOD STORE — TPI: verificación de sql/procedimientos.sql
-- Objetivo 6 + características PostgreSQL (JSONB, CALL, tabla
-- de transición). Se ejecuta sobre la copia de trabajo:
--   & $psql -d food_store_tp5 -f sql/procedimientos.sql
--   & $psql -d food_store_tp5 -f sql/prueba_procedimientos_TPI.sql
-- Usa datos de demostración (productos 1-3, cliente 1) y deja una
-- fila de auditoría como evidencia.
-- ============================================================

\pset border 2
\set ON_ERROR_STOP on

\echo '=== 1) Procedimiento CALL: registrar_reposicion (productos 1-3) ==='
CALL registrar_reposicion(1, 20);
CALL registrar_reposicion(2, 20);
CALL registrar_reposicion(3, 20);

SELECT id, nombre, stock FROM producto WHERE id IN (1, 2, 3) ORDER BY id;

\echo '=== 2) Reposición inválida: cantidad <= 0 y producto descartado ==='
\set ON_ERROR_STOP off
CALL registrar_reposicion(2, 0);
\echo '^ ERROR esperado: cantidad no positiva (P0001)'
CALL registrar_reposicion(999999, 5);
\echo '^ ERROR esperado: producto inexistente/inactivo (P0001)'
\set ON_ERROR_STOP on

\echo '=== 3) Transacción demo: pedido + 3 líneas con tabla de transición ==='
BEGIN;
INSERT INTO pedido (cliente_id, forma_pago) VALUES (1, 'EFECTIVO')
RETURNING id AS demo_pedido \gset
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario) VALUES
    (:'demo_pedido', 1, 2, (SELECT precio FROM producto WHERE id = 1)),
    (:'demo_pedido', 2, 1, (SELECT precio FROM producto WHERE id = 2)),
    (:'demo_pedido', 3, 3, (SELECT precio FROM producto WHERE id = 3));

\echo '--- auditoria_carga_lineas: 1 fila por SENTENCIA (3 líneas) ---'
SELECT n_lineas, monto_total, inserted_at
  FROM auditoria_carga_lineas
 WHERE id = (SELECT max(id) FROM auditoria_carga_lineas);

\echo '=== 4) Funciones de negocio ==='
SELECT calcular_total_pedido(:'demo_pedido') AS total_pedido_demo;

SELECT calcular_total_pedido(:'demo_pedido') =
       (SELECT SUM(cantidad * precio_unitario)
          FROM detalle_pedido WHERE pedido_id = :'demo_pedido')
    AS total_proviene_de_lineas;

SELECT resumen_pedido_jsonb(:'demo_pedido') -> 'cliente' ->> 'nombre' AS nombre_cliente,
       resumen_pedido_jsonb(:'demo_pedido') -> 'lineas' -> 0 ->> 'producto' AS primer_producto_jsonb;

\echo '--- JSONB completo (pretty) ---'
SELECT jsonb_pretty(resumen_pedido_jsonb(:'demo_pedido'));
COMMIT;

\echo '=== 5) La fila de auditoría persiste tras COMMIT (evidencia) ==='
SELECT id, n_lineas, monto_total, inserted_at
  FROM auditoria_carga_lineas
 WHERE id = (SELECT max(id) FROM auditoria_carga_lineas);

\echo '=== 6) Atomicidad: ROLLBACK revierte también la auditoría ==='
SELECT count(*) AS filas_auditoria_antes FROM auditoria_carga_lineas;
BEGIN;
INSERT INTO pedido (cliente_id, forma_pago) VALUES (1, 'TARJETA')
RETURNING id AS otras_pedido \gset
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario) VALUES
    (:'otras_pedido', 1, 1, 9.99);
SELECT count(*) AS filas_auditoria_en_tx FROM auditoria_carga_lineas;
ROLLBACK;
SELECT count(*) AS filas_auditoria_tras_rollback FROM auditoria_carga_lineas;

\echo '=== 7) Verificación final: catálogo de objetos nuevos ==='
SELECT p.proname AS nombre,
       CASE p.prokind WHEN 'f' THEN 'FUNCTION' WHEN 'p' THEN 'PROCEDURE' END AS tipo
  FROM pg_proc p
 WHERE p.proname IN ('calcular_total_pedido', 'resumen_pedido_jsonb',
                     'registrar_reposicion', 'auditar_carga_detalle_pedido')
 ORDER BY 1;
SELECT tgname AS nombre_trigger,
       tgrelid::regclass AS tabla,
       CASE tgtype & 1 WHEN 1 THEN 'ROW' ELSE 'STATEMENT' END AS nivel,
       CASE tgtype & 2 WHEN 2 THEN 'BEFORE' ELSE 'AFTER' END   AS momento,
       (tgtype & 4) > 0 AS sobre_insert
  FROM pg_trigger
 WHERE tgname = 'trg_detalle_auditoria_carga';