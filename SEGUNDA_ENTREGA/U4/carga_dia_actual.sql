-- ============================================================
-- FOOD STORE — Unidad 4 (TP6) · Soporte: carga del día actual
--
-- Por qué este script existe
-- -------------------------
-- La consulta del punto 5.1 filtra por el día corriente. La base
-- heredada de TP3/5 sembró 200.000 pedidos con
--     now() - (random() * interval '365 days')
-- es decir, ~580 pedidos por día, y su último día con datos es el
-- 2026-09-22. Con esa distribución el día corriente tiene 0 pedidos:
-- EXPLAIN ANALYZE mediría un conjunto vacío y el plan no diría nada
-- sobre el costo real del recorrido de las cuatro tablas.
--
-- Para que la medición de la Parte 2 sea representativa se carga un
-- día corriente con volumen equivalente al día MÁS CARGADO ya
-- presente en la propia base (2026-09-22: 12.269 pedidos). Se toman
-- 15.000 pedidos, un 22 % por encima de ese pico observado, y se
-- reparte entre las 3 categorías con la misma distribución de
-- estados y de líneas (1 a 4) que usa sql/carga_masiva.sql.
--
-- No se inventa un volumen descabellado: se escala con evidencia
-- que ya está en la base.
--
-- Uso (sobre la COPIA de trabajo food_store_tp6):
--   & $psql -U postgres -d food_store_tp6 -f TP6/carga_dia_actual.sql
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 0) R9 (stock) fuera de juego durante la carga masiva.
--    Mismo criterio que sql/carga_masiva.sql: son 37.500 líneas de
--    laboratorio y el trigger hace un UPDATE de producto por línea
--    (37.500 UPDATEs) que no aporta nada a la medición del reporte.
--    Se vuelve a encender al final del script.
-- ------------------------------------------------------------
ALTER TABLE detalle_pedido DISABLE TRIGGER trg_detalle_stock;

-- ------------------------------------------------------------
-- 1) Resincroniza las secuencias identity con el id máximo real.
--    Las identity no se revierten con ROLLBACK (nextval no es
--    transaccional): sin esto un reintento rompería los rangos.
-- ------------------------------------------------------------
SELECT setval(pg_get_serial_sequence('pedido', 'id'),
              COALESCE((SELECT max(id) FROM pedido), 0) + 1, FALSE);
SELECT setval(pg_get_serial_sequence('detalle_pedido', 'id'),
              COALESCE((SELECT max(id) FROM detalle_pedido), 0) + 1, FALSE);

-- ------------------------------------------------------------
-- 2) 15.000 pedidos del día corriente.
--    - fecha repartida dentro del día (hasta 23:59) para que el día
--      esté poblado sea cual sea la hora en que se corra el TP.
--    - cliente_id entre 1 y 20.003 (los existentes).
--    - estado con la misma mezcla de carga masiva: mayoría
--      ENTREGADO, y PENDIENTE / EN_PREPARACION / CANCELADO para
--      que el filtro de baja lógica del reporte tenga algo que
--      descartar de verdad.
-- ------------------------------------------------------------
INSERT INTO pedido (fecha, cliente_id, forma_pago, estado, created_at)
SELECT CURRENT_DATE + (random() * interval '23 hours 59 minutes'),
       1 + floor(random() * 20003)::bigint,
       (ARRAY['EFECTIVO', 'TARJETA', 'TRANSFERENCIA'])[
           1 + floor(random() * 3)::int]::forma_pago,
       (ARRAY['ENTREGADO', 'ENTREGADO', 'ENTREGADO',
              'EN_PREPARACION', 'PENDIENTE', 'CANCELADO'])[
           1 + floor(random() * 6)::int]::estado_pedido,
       CURRENT_DATE + (random() * interval '23 hours 59 minutes')
FROM generate_series(1, 15000) AS i;

-- ------------------------------------------------------------
-- 3) Sus líneas: de 1 a 4 por pedido (módulo de la posición, igual
--    que la carga masiva), producto pseudoaleatorio
--    DETERMINÍSTICO por línea (hash) para que dos líneas del mismo
--    pedido nunca repitan producto y violen
--    uq_detalle_pedido_producto. precio_unitario = producto.precio
--    (R4: el precio se congela en la línea).
-- ------------------------------------------------------------
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
SELECT p.id,
       (p.id * 2654435761 + ln) % 50000 + 1 AS producto_id,
       1 + floor(random() * 5)::int         AS cantidad,
       pr.precio
FROM (
    SELECT id, 1 + (row_number() OVER (ORDER BY id) % 4) AS n_lineas
    FROM pedido
    WHERE fecha >= CURRENT_DATE
      AND fecha <  CURRENT_DATE + INTERVAL '1 day'
) AS p
CROSS JOIN LATERAL generate_series(1, p.n_lineas) AS ln
JOIN producto pr ON pr.id = (p.id * 2654435761 + ln) % 50000 + 1;

ALTER TABLE detalle_pedido ENABLE TRIGGER trg_detalle_stock;

COMMIT;

-- ------------------------------------------------------------
-- 4) Estadísticas al cantidad de filas del día (obligatorio antes
--    de EXPLAIN ANALYZE: sin stats el optimizador estima mal).
-- ------------------------------------------------------------
ANALYZE pedido;
ANALYZE detalle_pedido;

-- ------------------------------------------------------------
-- CONTROLES ESPERADOS
-- ------------------------------------------------------------
--   pedidos del día      15.000
--   líneas del día       37.500  (1 a 4 por pedido, promedio 2,5)
--   pedidos_hoy con el predicado literal del enunciado
--   (fecha = CURRENT_DATE)          0   <- ver 5.2(a): TIMESTAMPTZ
--                                                    contra DATE
--   pedidos_hoy con el predicado de rango        15.000
--   pedidos_hoy no cancelados (equivalente a eliminado = FALSE)
--                                       ~12.500