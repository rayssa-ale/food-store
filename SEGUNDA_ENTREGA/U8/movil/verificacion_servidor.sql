-- Se ejecuta antes y despues de los casos C2-C6.
-- Si la tablet respeta la regla de oro, estas cifras no cambian.
SELECT 'pedidos'       AS metrica, count(*)::text              AS valor FROM pedido
UNION ALL
SELECT 'detalle_pedido', count(*)::text                        FROM detalle_pedido
UNION ALL
SELECT 'productos',      count(*)::text                        FROM producto
UNION ALL
SELECT 'stock_total',    COALESCE(sum(stock), 0)::text         FROM producto
UNION ALL
SELECT 'productos_activos', count(*) FILTER (WHERE activo)::text FROM producto;
