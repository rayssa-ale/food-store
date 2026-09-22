-- ============================================================
-- FOOD STORE — TP5 Parte B: verificación de equivalencia de vistas
-- Cada vista se compara contra su consulta manual equivalente (la
-- misma SELECT SIN la capa de vista) con EXCEPT en ambas direcciones.
-- 0 filas + igual número de filas = resultado idéntico.
-- Base: food_store_tp5.
-- ============================================================

-- V1: v_reporte_productos_vigentes vs consulta manual --------------
SELECT 'v1_filas' AS chequeo, (SELECT count(*) FROM v_reporte_productos_vigentes) AS a,
       (SELECT count(*) FROM producto p JOIN categoria c ON c.id = p.categoria_id
        WHERE p.activo AND c.activo) AS b;
SELECT 'v1_menos_manual' AS chequeo, count(*) AS filas FROM (
    (SELECT * FROM v_reporte_productos_vigentes)
    EXCEPT
    (SELECT p.id, p.nombre, p.descripcion, p.precio, p.stock, c.nombre AS categoria
     FROM producto p JOIN categoria c ON c.id = p.categoria_id
     WHERE p.activo AND c.activo)
) t;
SELECT 'v1_manual_menos' AS chequeo, count(*) AS filas FROM (
    (SELECT p.id, p.nombre, p.descripcion, p.precio, p.stock, c.nombre AS categoria
     FROM producto p JOIN categoria c ON c.id = p.categoria_id
     WHERE p.activo AND c.activo)
    EXCEPT
    (SELECT * FROM v_reporte_productos_vigentes)
) t;

-- V2: v_reporte_pedidos_cliente vs consulta manual -----------------
SELECT 'v2_filas' AS chequeo, (SELECT count(*) FROM v_reporte_pedidos_cliente) AS a,
       (SELECT count(*) FROM pedido pe JOIN cliente c ON c.id = pe.cliente_id) AS b;
SELECT 'v2_menos_manual' AS chequeo, count(*) AS filas FROM (
    (SELECT * FROM v_reporte_pedidos_cliente)
    EXCEPT
    (SELECT pe.id AS pedido_id, pe.fecha, pe.estado, pe.forma_pago,
            c.id AS cliente_id, c.nombre, c.apellido, c.email
     FROM pedido pe JOIN cliente c ON c.id = pe.cliente_id)
) t;
SELECT 'v2_manual_menos' AS chequeo, count(*) AS filas FROM (
    (SELECT pe.id AS pedido_id, pe.fecha, pe.estado, pe.forma_pago,
            c.id AS cliente_id, c.nombre, c.apellido, c.email
     FROM pedido pe JOIN cliente c ON c.id = pe.cliente_id)
    EXCEPT
    (SELECT * FROM v_reporte_pedidos_cliente)
) t;

-- V3: v_reporte_detalle_pedido vs consulta manual ------------------
SELECT 'v3_filas' AS chequeo, (SELECT count(*) FROM v_reporte_detalle_pedido) AS a,
       (SELECT count(*) FROM detalle_pedido d JOIN pedido pe ON pe.id = d.pedido_id
        JOIN producto p ON p.id = d.producto_id) AS b;
SELECT 'v3_menos_manual' AS chequeo, count(*) AS filas FROM (
    (SELECT * FROM v_reporte_detalle_pedido)
    EXCEPT
    (SELECT d.id AS linea_id, pe.id AS pedido_id, pe.fecha, p.id AS producto_id,
            p.nombre AS producto, d.cantidad, d.precio_unitario,
            (d.cantidad * d.precio_unitario) AS importe
     FROM detalle_pedido d JOIN pedido pe ON pe.id = d.pedido_id
     JOIN producto p ON p.id = d.producto_id)
) t;
SELECT 'v3_manual_menos' AS chequeo, count(*) AS filas FROM (
    (SELECT d.id AS linea_id, pe.id AS pedido_id, pe.fecha, p.id AS producto_id,
            p.nombre AS producto, d.cantidad, d.precio_unitario,
            (d.cantidad * d.precio_unitario) AS importe
     FROM detalle_pedido d JOIN pedido pe ON pe.id = d.pedido_id
     JOIN producto p ON p.id = d.producto_id)
    EXCEPT
    (SELECT * FROM v_reporte_detalle_pedido)
) t;

-- V4: v_cliente_contacto (seguridad) vs consulta manual ------------
SELECT 'v4_filas' AS chequeo, (SELECT count(*) FROM v_cliente_contacto) AS a,
       (SELECT count(*) FROM cliente) AS b;
SELECT 'v4_menos_manual' AS chequeo, count(*) AS filas FROM (
    (SELECT * FROM v_cliente_contacto)
    EXCEPT
    (SELECT c.id, c.nombre, c.apellido, c.email FROM cliente c)
) t;
SELECT 'v4_manual_menos' AS chequeo, count(*) AS filas FROM (
    (SELECT c.id, c.nombre, c.apellido, c.email FROM cliente c)
    EXCEPT
    (SELECT * FROM v_cliente_contacto)
) t;

-- Comprobación de que telefono NO se expone por la vista de seguridad.
SELECT 'v4_no_expone_telefono' AS chequeo, count(*) AS columnas_telefono
FROM information_schema.columns
WHERE table_name = 'v_cliente_contacto' AND column_name = 'telefono';