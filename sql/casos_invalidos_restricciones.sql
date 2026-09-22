-- ============================================================
-- FOOD STORE — Casos INVÁLIDOS (Parte 1)
-- Cada caso corre dentro de SU PROPIA transacción. El error que
-- dispara el trigger deja la transacción abortada y se hace
-- ROLLBACK. La existencia del ERROR es la evidencia de que la
-- regla quedó garantizada por el motor.
-- ============================================================

-- I1 — R8: no se puede volver de EN_PREPARACION a PENDIENTE.
BEGIN;
UPDATE pedido SET estado = 'PENDIENTE' WHERE id = 2;
ROLLBACK;

-- I2 — R8: un pedido ENTREGADO está congelado (no se puede cancelar).
BEGIN;
UPDATE pedido SET estado = 'CANCELADO' WHERE id = 1;
ROLLBACK;

-- I3 — R9: no se venden más unidades de las disponibles
--      (producto 6 tiene stock 12; se piden 9999).
BEGIN;
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
VALUES (2, 6, 9999, 950.00);
ROLLBACK;

-- I4 — R10: el precio unitario de una línea ya creada no se modifica.
BEGIN;
UPDATE detalle_pedido SET precio_unitario = 500.00 WHERE id = 1;
ROLLBACK;

-- Control final: los datos quedan intactos luego de los rechazos.
SELECT (SELECT count(*) FROM pedido)              AS pedidos,
       (SELECT count(*) FROM detalle_pedido)      AS detalle_total,
       (SELECT count(*) FROM detalle_pedido WHERE pedido_id = 2) AS lineas_pedido_2;