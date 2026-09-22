-- ============================================================
-- FOOD STORE — TP5 Parte C: materializadas.sql
-- Vista materializada de un reporte agregado costoso, WITH DATA,
-- con índice ÚNICO que habilita REFRESH CONCURRENTLY.
-- Especificación: specs/materializada_facturacion_categoria_mes_pago.md.
-- Base: food_store_tp5.
-- ============================================================

-- Facturación por categoría, mes y forma de pago (solo ENTREGADO).
CREATE MATERIALIZED VIEW mv_facturacion_categoria_mes_pago AS
SELECT c.nombre               AS categoria,
       date_trunc('month', pe.fecha) AS mes,
       pe.forma_pago,
       SUM(d.cantidad * d.precio_unitario) AS facturado,
       COUNT(*)                           AS lineas
FROM detalle_pedido d
JOIN pedido   pe ON pe.id = d.pedido_id
JOIN producto p  ON p.id = d.producto_id
JOIN categoria c ON c.id = p.categoria_id
WHERE pe.estado = 'ENTREGADO'
GROUP BY c.nombre, date_trunc('month', pe.fecha), pe.forma_pago
WITH DATA;

-- Índice ÚNICO: garantiza unicidad por (categoria, mes, forma_pago)
-- y es el requisito de PostgreSQL para REFRESH ... CONCURRENTLY.
CREATE UNIQUE INDEX uq_mv_facturacion_cat_mes_pago
    ON mv_facturacion_categoria_mes_pago (categoria, mes, forma_pago);

-- Índice de soporte para las lecturas por mes.
CREATE INDEX ix_mv_facturacion_mes
    ON mv_facturacion_categoria_mes_pago (mes);

ANALYZE mv_facturacion_categoria_mes_pago;