-- ============================================================
-- FOOD STORE — TP5 Parte B: views.sql
-- Vistas para los reportes habituales del sistema + una vista de
-- seguridad. Generadas por OpenCode a partir de las
-- especificaciones de specs/ (entregable Kiro).
-- No modifican schema.sql: solo exponen lectura por encima.
-- La equivalencia de cada una contra su consulta manual se
-- verifica en sql/verificacion_views.sql (EXCEPT 0/0).
-- Base: food_store_tp5.
-- ============================================================

-- ------------------------------------------------------------
-- v_reporte_productos_vigentes — carta vigente con su rubro.
-- Oculto: created_at de producto y categoría.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_reporte_productos_vigentes AS
SELECT p.id,
       p.nombre,
       p.descripcion,
       p.precio,
       p.stock,
       c.nombre AS categoria
FROM producto p
JOIN categoria c ON c.id = p.categoria_id
WHERE p.activo AND c.activo;

-- ------------------------------------------------------------
-- v_reporte_pedidos_cliente — pedidos con los datos del cliente.
-- Oculto: created_at de ambas, telefono del cliente (queda para
-- la vista de seguridad v_cliente_contacto).
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_reporte_pedidos_cliente AS
SELECT pe.id        AS pedido_id,
       pe.fecha,
       pe.estado,
       pe.forma_pago,
       c.id         AS cliente_id,
       c.nombre,
       c.apellido,
       c.email
FROM pedido pe
JOIN cliente c ON c.id = pe.cliente_id;

-- ------------------------------------------------------------
-- v_reporte_detalle_pedido — detalle de pedido con nombre del
-- producto e importe derivado (R4: NUMERIC, nunca almacenado).
-- Oculto: descripcion y created_at.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_reporte_detalle_pedido AS
SELECT d.id                        AS linea_id,
       pe.id                       AS pedido_id,
       pe.fecha,
       p.id                        AS producto_id,
       p.nombre                    AS producto,
       d.cantidad,
       d.precio_unitario,
       (d.cantidad * d.precio_unitario) AS importe
FROM detalle_pedido d
JOIN pedido   pe ON pe.id = d.pedido_id
JOIN producto p  ON p.id = d.producto_id;

-- ------------------------------------------------------------
-- v_cliente_contacto — vista de SEGURIDAD.
-- Expone al cliente SIN datos personales no imprescindibles.
-- (Adaptación: schema sin "contraseña"; el dato personal que se
-- oculta es telefono, ver spec vista_cliente_contacto_seguridad.md.)
-- Permisos (producción): REVOKE SELECT ON cliente FROM rol_ventas;
-- GRANT SELECT ON v_cliente_contacto TO rol_ventas;
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_cliente_contacto AS
SELECT c.id,
       c.nombre,
       c.apellido,
       c.email
FROM cliente c;