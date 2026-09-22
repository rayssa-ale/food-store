-- ============================================================
-- FOOD STORE — TP3 Parte 1: carga masiva generada por IA
-- Spec aplicada (prompt, resumen):
--   "Generá un script SQL para PostgreSQL que inserte 50.000
--    filas en producto, distribuidas de forma pareja entre las
--    categorías existentes, con precios entre 500 y 5000 y stock
--    aleatorio entre 0 y 200. Usá generate_series y no uses
--    PL/pgSQL si no es necesario. No modifiques ninguna otra
--    tabla."  (ajustada: además 20.000 clientes y 200.000
--    pedidos con detalles, según consigna de la Parte 1)
--
-- Reglas que debe respetar el script (revisadas línea por línea):
--   * FK: categoria -> producto -> detalle; pedido -> cliente.
--   * CHECK: precio >= 0, stock >= 0, cantidad > 0, precio_unitario >= 0.
--   * R6 email UNIQUE, R1 producto con categoria_id válida.
--   * Solo INSERT sobre la COPIA (food_store_tp3), nunca producción.
--   * Ejecutar dentro de una transacción (este archivo trae
--     BEGIN/COMMIT) y luego ANALYZE.
-- ============================================================

BEGIN;

-- Resincroniza las secuencias identity con el último id real: las
-- identity NO se revierten al hacer ROLLBACK (nextval no es
-- transaccional), así que un reintento tras un fallo dejaría
-- huecos de ids y rompería los rangos que las FK esperan.
SELECT setval(pg_get_serial_sequence('producto', 'id'),      COALESCE((SELECT max(id) FROM producto), 0) + 1, FALSE);
SELECT setval(pg_get_serial_sequence('cliente', 'id'),       COALESCE((SELECT max(id) FROM cliente), 0)  + 1, FALSE);
SELECT setval(pg_get_serial_sequence('pedido', 'id'),        COALESCE((SELECT max(id) FROM pedido), 0)   + 1, FALSE);
SELECT setval(pg_get_serial_sequence('detalle_pedido', 'id'),COALESCE((SELECT max(id) FROM detalle_pedido), 0) + 1, FALSE);

-- ------------------------------------------------------------
-- 1) producto: 50.000 filas repartidas parejo entre categorías
--    (módulo 3), precio 500–5000, stock 0–200, todas activas.
--    La fecha de alta se dispersa en el último año.
-- ------------------------------------------------------------
INSERT INTO producto (nombre, descripcion, precio, stock, categoria_id, activo, created_at)
SELECT 'Producto ' || lpad(i::text, 6, '0'),
       'Generado por IA para el laboratorio TP3 (batch ' || (i % 10) || ')',
       (500 + floor(random() * 4501))::numeric,            -- 500 .. 5000
       floor(random() * 201)::int,                          -- 0 .. 200
       (1 + (i % 3)),                                       -- 1..3 (categorías existentes)
       TRUE,
       now() - (random() * interval '365 days')
FROM generate_series(1, 50000) AS i;

-- ------------------------------------------------------------
-- 2) cliente: 20.000 usuarios (email único R6), teléfono 351...
-- ------------------------------------------------------------
INSERT INTO cliente (nombre, apellido, email, telefono)
SELECT 'Nombre' || i,
       'Apellido' || i,
       'cliente' || i || '@foodstore.com',
       '351' || lpad((i % 10000000)::text, 7, '0')
FROM generate_series(1, 20000) AS i;

-- ------------------------------------------------------------
-- 3) pedido: 200.000 pedidos.
--    cliente_id repartido (1..20003 = seed + 20.000 nuevos),
--    forma_pago cerrada (R3) al azar, estado con distribución
--    realista, fecha dispersa en el último año.
--    La tabla NO acumula total (diseño 3FN): solo líneas.
-- ------------------------------------------------------------
INSERT INTO pedido (fecha, cliente_id, forma_pago, estado, created_at)
SELECT now() - (random() * interval '365 days'),
       1 + floor(random() * 20003)::bigint,                 -- algunos clientes sin pedidos
       (ARRAY['EFECTIVO', 'TARJETA', 'TRANSFERENCIA'])[1 + floor(random() * 3)::int]::forma_pago,
       (ARRAY['ENTREGADO', 'ENTREGADO', 'ENTREGADO',
              'EN_PREPARACION', 'PENDIENTE', 'CANCELADO'])[1 + floor(random() * 6)::int]::estado_pedido,
       now() - (random() * interval '365 days')
FROM generate_series(1, 200000) AS i;

-- ------------------------------------------------------------
-- 4) detalle_pedido: de 1 a 4 líneas por pedido (determinístico:
--    el módulo de la posición fija cuántas líneas tiene cada
--    pedido, garantizando >= 1), producto pseudoaleatorio DETER-
--    MINÍSTICO por línea (función hash) para que dos líneas del
--    mismo pedido nunca repitan producto y pisar el UNIQUE
--    (pedido_id, producto_id). cantidad 1–5 al azar y
--    precio_unitario = producto.precio (R4).
--    Nota: esta copia de laboratorio no lleva el trigger R9
--    (stock) para medir el costo puro de las consultas.
-- ------------------------------------------------------------
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
SELECT p.id,
       (p.id * 2654435761 + ln) % 50000 + 1 AS producto_id,
       1 + floor(random() * 5)::int         AS cantidad,
       pr.precio
FROM (
    SELECT id, 1 + (row_number() OVER (ORDER BY id) % 4) AS n_lineas
    FROM pedido
) AS p
CROSS JOIN LATERAL generate_series(1, p.n_lineas) AS ln
JOIN producto pr ON pr.id = (p.id * 2654435761 + ln) % 50000 + 1;

COMMIT;

-- ============================================================
-- POST-CARGA (parte 3 de la consigna, pasos a ejecutar aparte):
--   ANALYZE folder de las tablas afectadas para actualizar
--   estadísticas del optimizador:
--
--   ANALYZE producto; ANALYZE cliente; ANALYZE pedido;
--   ANALYZE detalle_pedido;
--
--   Controles de cantidad esperados:
--     producto      50.000 + 6   = 50.006
--     cliente       20.000 + 3   = 20.003
--     pedido        200.000 + 3  = 200.003
--     detalle_pedido ~500.000    (1–4 líneas por pedido, avg 2,5)
-- ============================================================