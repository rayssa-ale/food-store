-- ============================================================
-- FOOD STORE — TP5 Parte A.5: prueba de escritura (FASE ANTES)
-- Correr ANTES de sql/indices.sql, sobre food_store_tp5.
-- Mide el costo de escritura BASE (sin los índices nuevos):
--   E1) carga de 6.000 pedidos nuevos (mantiene existing índices)
--   E2) carga de 6.000 líneas sobre esos pedidos
-- Los índices nuevos son de pedido/producto/cliente, no de
-- detalle_pedido: la comparación E2 muestra si la escritura de
-- líneas cambia (no debería) y E1 muestra el costo real del índice
-- compuesto nuevo. Uso con \timing on.
-- ============================================================

\timing on

-- E1 — 6.000 pedidos nuevos (PENDIENTE, una sola fecha de corte).
INSERT INTO pedido (cliente_id, forma_pago, estado, fecha)
SELECT c.id, 'EFECTIVO', 'PENDIENTE', '2026-09-22 10:00:00-03'
FROM (SELECT id FROM cliente ORDER BY id LIMIT 6000) c;

-- E2 — 6.000 líneas, una por pedido recién creado (producto fijo 1):
--      pares (pedido_id, 1) únicos porque esos pedidos no tienen líneas.
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
SELECT pe.id, 1, 1, 100.00
FROM pedido pe
WHERE pe.fecha = '2026-09-22 10:00:00-03'
ORDER BY pe.id
LIMIT 6000;