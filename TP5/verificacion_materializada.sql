-- ============================================================
-- FOOD STORE — TP5 Parte C: verificación de equivalencia de la MV
-- mv_facturacion_categoria_mes_pago contra la consulta original.
-- EXCEPT en ambas direcciones -> 0 filas = resultados idénticos.
-- ============================================================

SELECT count(*) AS mv_menos_original FROM (
    (SELECT categoria, mes, forma_pago, facturado, lineas
     FROM mv_facturacion_categoria_mes_pago)
    EXCEPT
    (SELECT c.nombre, date_trunc('month', pe.fecha) AS mes, pe.forma_pago,
            SUM(d.cantidad * d.precio_unitario) AS facturado, COUNT(*) AS lineas
     FROM detalle_pedido d
     JOIN pedido   pe ON pe.id = d.pedido_id
     JOIN producto p  ON p.id = d.producto_id
     JOIN categoria c ON c.id = p.categoria_id
     WHERE pe.estado = 'ENTREGADO'
     GROUP BY c.nombre, date_trunc('month', pe.fecha), pe.forma_pago)
) t;

SELECT count(*) AS original_menos_mv FROM (
    (SELECT c.nombre, date_trunc('month', pe.fecha) AS mes, pe.forma_pago,
            SUM(d.cantidad * d.precio_unitario) AS facturado, COUNT(*) AS lineas
     FROM detalle_pedido d
     JOIN pedido   pe ON pe.id = d.pedido_id
     JOIN producto p  ON p.id = d.producto_id
     JOIN categoria c ON c.id = p.categoria_id
     WHERE pe.estado = 'ENTREGADO'
     GROUP BY c.nombre, date_trunc('month', pe.fecha), pe.forma_pago)
    EXCEPT
    (SELECT categoria, mes, forma_pago, facturado, lineas
     FROM mv_facturacion_categoria_mes_pago)
) t;

-- Refresco concurrente (prueba de que el índice único lo habilita;
-- no altera el resultado porque no hay datos nuevos aún).
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes_pago;