-- ============================================================
-- FOOD STORE — TP5 (Semana 5): queries de la carga de trabajo
-- Tres consultas FRECUENTES del sistema que hoy resuelven con
-- Seq Scan sobre una tabla considerable (se miden con EXPLAIN
-- ANALYZE vía runner). Fuente: queries.sql de Semanas 3-4 y
-- reportes operativos del negocio.
-- Base: food_store_tp5 (200k pedidos, 500k líneas, 50k productos,
-- 20k clientes). No se modifica el modelo de datos.
-- ============================================================

-- ------------------------------------------------------------
-- A1 — Reporte de gerencia: todos los pedidos de un mes (cualquier
--      estado), ordenados por fecha. No existe índice con fecha como
--      columna líder, por eso hoy resuelve con Seq Scan sobre los
--      200 k pedidos. La pestaña mensual corre 1×/día o bajo demanda.
--      El mismo índice compuesto (fecha, estado) sirve también para
--      la variante que filtra estado = 'ENTREGADO' (dashboard).
-- ------------------------------------------------------------
SELECT pe.id, pe.fecha, pe.estado, pe.forma_pago, pe.cliente_id
FROM pedido pe
WHERE pe.fecha >= '2026-01-01' AND pe.fecha < '2026-02-01'
ORDER BY pe.fecha, pe.id;

-- ------------------------------------------------------------
-- A2 — Reporte operativo: productos a reponer (stock bajo), primeros
--      N del ranking. Corre varias veces al día en el local.
-- ------------------------------------------------------------
SELECT p.id, p.nombre, p.precio, p.stock
FROM producto p
WHERE p.activo AND p.stock < 50
ORDER BY p.stock, p.id
LIMIT 100;

-- ------------------------------------------------------------
-- A3 — Búsqueda de clientes por apellido (panel atención/caja),
--      con orden alfabético y paginación. Corre decenas de veces/día.
-- ------------------------------------------------------------
SELECT c.nombre, c.apellido, c.email
FROM cliente c
WHERE c.apellido LIKE 'Apellido15%'
ORDER BY c.apellido, c.nombre
LIMIT 20;

-- ------------------------------------------------------------
-- D1 — (Prueba de descarte) Top 10 productos más vendidos por
--      unidades. Se usa para VERIFICAR que un índice en cantidad
--      no cambia el plan (agregación de tabla completa).
-- ------------------------------------------------------------
SELECT p.id, p.nombre, SUM(d.cantidad) AS unidades
FROM detalle_pedido d
JOIN producto p ON p.id = d.producto_id
GROUP BY p.id, p.nombre
ORDER BY unidades DESC
LIMIT 10;