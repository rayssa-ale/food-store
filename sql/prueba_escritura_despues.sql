-- ============================================================
-- FOOD STORE — TP5 Parte A.5: prueba de escritura (FASE DESPUÉS)
-- Correr DESPUÉS de sql/indices.sql, sobre food_store_tp5.
-- Misma forma que prueba_escritura_antes.sql pero con una fecha de
-- corte distinta (11:00) para apuntar a otra tanda de pedidos.
--   E3) carga de 6.000 pedidos nuevos → mantiene ix_pedido_fecha_estado
--   E4) carga de 6.000 líneas sobre esos pedidos → los índices nuevos
--       NO están sobre detalle_pedido, por lo que no debería variar.
-- ============================================================

\timing on

-- E3 — 6.000 pedidos nuevos (nueva tanda).
INSERT INTO pedido (cliente_id, forma_pago, estado, fecha)
SELECT c.id, 'EFECTIVO', 'PENDIENTE', '2026-09-22 11:00:00-03'
FROM (SELECT id FROM cliente ORDER BY id DESC LIMIT 6000) c;

-- E4 — 6.000 líneas sobre la nueva tanda (producto fijo 1).
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
SELECT pe.id, 1, 1, 100.00
FROM pedido pe
WHERE pe.fecha = '2026-09-22 11:00:00-03'
ORDER BY pe.id
LIMIT 6000;