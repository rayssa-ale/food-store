-- ============================================================
-- FOOD STORE — TP3 Parte 2: queries.sql
-- Consultas reales del modelo sobre la base masiva (50k/20k/200k).
-- Se usan 4 candidatas a lentas para el laboratorio EXPLAIN;
-- Q6 es la consulta fija de la competencia (Parte 5).
-- ============================================================

-- Q1 — Carta vigente: productos de una categoría con filtro de
--      precio, ordenados por nombre. Se pide la categoría "Pizzas"
--      con precio entre 700 y 4500 y un tope de filas.
SELECT p.id, p.nombre, p.precio, p.stock
FROM producto p
JOIN categoria c ON c.id = p.categoria_id
WHERE c.nombre = 'Pizzas'
  AND p.activo = TRUE
  AND p.precio BETWEEN 700 AND 4500
ORDER BY p.nombre, p.id
LIMIT 50;

-- Q2 — Historial de pedidos de un cliente, más recientes primero
--      y solo estados no cancelados (panel de cliente).
SELECT pe.id, pe.fecha, pe.forma_pago, pe.estado,
       SUM(d.cantidad * d.precio_unitario) AS total
FROM pedido pe
JOIN detalle_pedido d ON d.pedido_id = pe.id
WHERE pe.cliente_id = 1421
  AND pe.estado <> 'CANCELADO'
GROUP BY pe.id, pe.fecha, pe.forma_pago, pe.estado
ORDER BY pe.fecha DESC
LIMIT 20;

-- Q3 — Top 10 productos más vendidos (cantidad total).
SELECT p.id, p.nombre, SUM(d.cantidad) AS unidades
FROM detalle_pedido d
JOIN producto p ON p.id = d.producto_id
GROUP BY p.id, p.nombre
ORDER BY unidades DESC
LIMIT 10;

-- Q4 — Ranking de facturación por cliente (top 20), tomando solo
--      pedidos ENTREGADO (ya cobrados).
SELECT c.id, c.nombre, c.apellido,
       SUM(d.cantidad * d.precio_unitario) AS facturado
FROM detalle_pedido d
JOIN pedido pe ON pe.id = d.pedido_id
JOIN cliente c  ON c.id = pe.cliente_id
WHERE pe.estado = 'ENTREGADO'
GROUP BY c.id, c.nombre, c.apellido
ORDER BY facturado DESC
LIMIT 20;

-- Q6 — Consulta fija de la competencia (Parte 5): listado de
--      productos por categoría con filtro de precio y orden, sin
--      índice dedicado (la clave (categoria_id, precio) no existe
--      en el schema_base).
SELECT p.id, p.nombre, p.precio, p.stock
FROM producto p
WHERE p.categoria_id = 2
  AND p.precio BETWEEN 600 AND 3000
  AND p.activo = TRUE
ORDER BY p.precio, p.id
LIMIT 100;