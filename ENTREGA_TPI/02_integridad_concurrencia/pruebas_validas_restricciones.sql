-- ============================================================
-- FOOD STORE — Pruebas de restricciones (Parte 1)
-- PROTOCOLO: se aplican los triggers y se prueban los casos
-- VÁLIDOS dentro de UNA transacción, y recién al final COMMIT.
--
-- Ejecución:
--   psql -d food_store_dev -f sql/pruebas_validas_restricciones.sql
-- ============================================================

BEGIN;

-- Aplica las restricciones R8, R9 y R10 (script entregado).
\i sql/restricciones.sql

-- ------------------------------------------------------------
-- Casos VÁLIDOS (deben ejecutarse sin error)
-- ------------------------------------------------------------

-- V1: avance de estado permitido PENDIENTE -> EN_PREPARACION (pedido 3).
UPDATE pedido SET estado = 'EN_PREPARACION' WHERE id = 3;

-- V2: carga de línea con stock suficiente: producto 5 (stock 30),
--     se piden 1 unidad. La venta debe descontar el stock a 29.
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
VALUES (3, 5, 1, 500.00);

-- V3: pedido nuevo en PENDIENTE se puede CANCELAR (estado no terminal).
INSERT INTO pedido (id, fecha, cliente_id, forma_pago, estado)
OVERRIDING SYSTEM VALUE
VALUES (4, now(), 3, 'TRANSFERENCIA', 'PENDIENTE');
UPDATE pedido SET estado = 'CANCELADO' WHERE id = 4;

-- Verificación de stock descontado: el producto 5 debe quedar en 29.
SELECT id, nombre, stock FROM producto WHERE id = 5;

COMMIT;