-- ============================================================
-- FOOD STORE — TPI: evidencia de reglas de negocio (R8-R10)
-- Demuestra en el MOTOR que las reglas se aplican: transición
-- válida e inválida (R8), stock suficiente e insuficiente (R9) y
-- precio congelado (R10). Cada caso inválido queda en su
-- SAVEPOINT y se revierte; la transacción termina en ROLLBACK:
-- no altera datos.
-- Requiere aplicar antes sql/restricciones.sql.
--   & $psql -d food_store_tp5 -f sql/evidencia_restricciones_TPI.sql
-- ============================================================
\pset pager off
\set ON_ERROR_STOP on
BEGIN;

\echo '=== R8 (valida): PENDIENTE -> EN_PREPARACION -> ENTREGADO ==='
INSERT INTO pedido (cliente_id, forma_pago) VALUES (1, 'EFECTIVO')
RETURNING id AS p \gset
UPDATE pedido SET estado = 'EN_PREPARACION' WHERE id = :'p' RETURNING id, estado;
UPDATE pedido SET estado = 'ENTREGADO'       WHERE id = :'p' RETURNING id, estado;

\echo '=== R8 (invalida): ENTREGADO -> CANCELADO (estado terminal) ==='
SAVEPOINT sp_r8;
\set ON_ERROR_STOP off
UPDATE pedido SET estado = 'CANCELADO' WHERE id = :'p';
\echo '^ esperado: ERROR R8 pedido en estado terminal'
\set ON_ERROR_STOP on
ROLLBACK TO SAVEPOINT sp_r8;

\echo '=== R9 (valida): la venta descuenta stock atomicamente ==='
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario) VALUES
    (:'p', 1, 2, (SELECT precio FROM producto WHERE id = 1))
RETURNING id, pedido_id, producto_id, cantidad, precio_unitario;
SELECT id, nombre, stock FROM producto WHERE id = 1;

\echo '=== R9 (invalida): stock insuficiente rechazado (producto 2) ==='
SAVEPOINT sp_r9;
\set ON_ERROR_STOP off
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario) VALUES
    (:'p', 2, 999999, 10);
\echo '^ esperado: ERROR R9 stock insuficiente'
\set ON_ERROR_STOP on
ROLLBACK TO SAVEPOINT sp_r9;

\echo '=== R10 (invalida): precio_unitario de la linea congelado ==='
SELECT id AS l FROM detalle_pedido ORDER BY id LIMIT 1 \gset
SAVEPOINT sp_r10;
\set ON_ERROR_STOP off
UPDATE detalle_pedido SET precio_unitario = precio_unitario + 100 WHERE id = :'l';
\echo '^ esperado: ERROR R10 precio congelado'
\set ON_ERROR_STOP on
ROLLBACK TO SAVEPOINT sp_r10;

\echo '=== Cierre: ROLLBACK no deja huella ==='
ROLLBACK;
SELECT count(*) AS lineas_demo_que_quedan
  FROM detalle_pedido WHERE pedido_id = :'p';