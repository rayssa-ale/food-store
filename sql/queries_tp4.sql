-- ============================================================
-- FOOD STORE — TP4 (Semana 4): queries.sql analíticas
-- Consultas reales de reporte que cruzan 3+ tablas con joins,
-- agregación, funciones de ventana y subconsultas correlacionadas.
-- Base masiva: food_store_tp3 (50.006 productos, 20.003 clientes,
-- 200.003 pedidos, 500.014 líneas — estado ENTREGADO = ~100.049).
-- Se miden con EXPLAIN (ANALYZE, BUFFERS) vía runner aparte.
-- ============================================================

-- ------------------------------------------------------------
-- T1 — Facturación por categoría y mes (pedidos ENTREGADO).
--      Cruza detalle_pedido + pedido + producto + categoria.
--      Reporte de gerencia: cuánto vendió cada rubro por mes.
-- ------------------------------------------------------------
SELECT c.nombre AS categoria,
       to_char(date_trunc('month', pe.fecha), 'YYYY-MM') AS mes,
       SUM(d.cantidad * d.precio_unitario)                 AS facturado,
       COUNT(*)                                            AS lineas
FROM detalle_pedido d
JOIN pedido   pe ON pe.id = d.pedido_id
JOIN producto p  ON p.id = d.producto_id
JOIN categoria c ON c.id = p.categoria_id
WHERE pe.estado = 'ENTREGADO'
GROUP BY c.nombre, date_trunc('month', pe.fecha)
ORDER BY mes, categoria;

-- ------------------------------------------------------------
-- T2 — Top 3 productos por categoría según recaudación
--      (ranking con función de ventana ROW_NUMBER).
--      Cruza detalle_pedido + producto + categoria.
-- ------------------------------------------------------------
SELECT categoria, puesto, nombre, recaudado
FROM (
    SELECT c.nombre AS categoria,
           p.nombre,
           SUM(d.cantidad * d.precio_unitario) AS recaudado,
           ROW_NUMBER() OVER (
               PARTITION BY c.nombre
               ORDER BY SUM(d.cantidad * d.precio_unitario) DESC
           ) AS puesto
    FROM detalle_pedido d
    JOIN producto p  ON p.id = d.producto_id
    JOIN categoria c ON c.id = p.categoria_id
    GROUP BY c.nombre, p.nombre
) t
WHERE puesto <= 3
ORDER BY categoria, puesto;

-- ------------------------------------------------------------
-- T3 — Top 50 pedidos por importe (no cancelados), con cliente
--      y cantidad de líneas por pedido.
--      Cruza pedido + cliente + detalle_pedido.
-- ------------------------------------------------------------
SELECT pe.id, c.nombre, c.apellido,
       COUNT(d.id)                         AS lineas,
       SUM(d.cantidad * d.precio_unitario) AS importe
FROM pedido pe
JOIN cliente c        ON c.id = pe.cliente_id
JOIN detalle_pedido d ON d.pedido_id = pe.id
WHERE pe.estado <> 'CANCELADO'
GROUP BY pe.id, c.nombre, c.apellido
ORDER BY importe DESC
LIMIT 50;

-- ------------------------------------------------------------
-- T4 — Clientes que compraron en TODAS las categorías vigentes
--      (subconsulta correlacionada con doble negación / NOT EXISTS).
--      Cruza cliente + pedido + detalle_pedido + producto + categoria.
-- ------------------------------------------------------------
SELECT c.id, c.nombre, c.apellido, c.email
FROM cliente c
WHERE NOT EXISTS (
    SELECT 1
    FROM categoria ca
    WHERE ca.activo
      AND NOT EXISTS (
          SELECT 1
          FROM pedido pe
          JOIN detalle_pedido d ON d.pedido_id = pe.id
          JOIN producto p  ON p.id = d.producto_id
          WHERE pe.cliente_id = c.id
            AND p.categoria_id = ca.id
      )
)
ORDER BY c.id;

-- ------------------------------------------------------------
-- T5 — Facturación mensual de clientes frecuentes con acumulado
--      (window running total). "Frecuente" = 5+ meses con ventas
--      ENTREGADO. Cruza pedido + detalle_pedido + cliente.
-- ------------------------------------------------------------
WITH compras AS (
    SELECT pe.cliente_id, date_trunc('month', pe.fecha) AS mes,
           SUM(d.cantidad * d.precio_unitario) AS facturado
    FROM pedido pe
    JOIN detalle_pedido d ON d.pedido_id = pe.id
    WHERE pe.estado = 'ENTREGADO'
    GROUP BY pe.cliente_id, date_trunc('month', pe.fecha)
)
SELECT c.id, c.nombre || ' ' || c.apellido AS nombre,
       to_char(m.mes, 'YYYY-MM') AS mes,
       m.facturado,
       SUM(m.facturado) OVER (PARTITION BY c.id ORDER BY m.mes) AS acumulado
FROM compras m
JOIN cliente c ON c.id = m.cliente_id
WHERE c.id IN (
    SELECT cliente_id FROM compras
    GROUP BY cliente_id HAVING COUNT(*) >= 5
)
ORDER BY c.id, m.mes;