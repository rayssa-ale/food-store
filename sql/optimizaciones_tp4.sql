-- ============================================================
-- FOOD STORE — TP4 Parte 1: optimizaciones propuestas por IA
-- Cada propuesta se justifica por el NODO de join/orden concreto
-- del plan real (docs/planes4/*_antes.txt). Se aplica SOLO lo que
-- puede explicarse; el resto se mide y documenta en la tabla.
-- ============================================================

-- ------------------------------------------------------------
-- OPT-T1 (aceptada): materialización analítica del reporte por
-- categoría y mes. Justificación en el plan:
--   el costo no está en los joins (Hash Join ×3 sobre 500k filas
--   en ~230 ms) sino en el Sort externo a disco para el
--   GroupAggregate (Sort Method: external merge Disk 3472kB) que
--   sigue a "Sort Key: c.nombre, mes". Un reporte de gerencia de
--   39 filas no justifica re-scanear 500k líneas por consulta:
--   se materializa el agregado y la consulta pasa a leer 39 filas.
-- ------------------------------------------------------------
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_ventas_categoria_mes AS
SELECT c.nombre AS categoria,
       date_trunc('month', pe.fecha)           AS mes,
       SUM(d.cantidad * d.precio_unitario)     AS facturado,
       COUNT(*)                                AS lineas
FROM detalle_pedido d
JOIN pedido   pe ON pe.id = d.pedido_id
JOIN producto p  ON p.id = d.producto_id
JOIN categoria c ON c.id = p.categoria_id
WHERE pe.estado = 'ENTREGADO'
GROUP BY c.nombre, date_trunc('month', pe.fecha)
WITH DATA;

-- Índice de soporte de la MV sobre (categoria, mes) y (mes).
CREATE INDEX IF NOT EXISTS ix_mv_ventas_cat_mes ON mv_ventas_categoria_mes (categoria, mes);
CREATE INDEX IF NOT EXISTS ix_mv_ventas_mes ON mv_ventas_categoria_mes (mes);

ANALYZE mv_ventas_categoria_mes;

-- ------------------------------------------------------------
-- OPT-T2 (aceptada como ajuste de entorno, NO índice):
--   Top-3 por categoría. El plan muestra el cuello REAL: los dos
--   Hash Join están en ~180 ms; lo que tarda 2,4 s es el
--   "Sort  Sort Key: c.nombre, p.nombre  Sort Method: external
--   merge  Disk: 8168kB" previo al GroupAggregate, que derrama a
--   disco (y el WindowAgg posterior). El índice no puede reducir
--   un agregado de tabla completa; el ajuste honesto es subir
--   work_mem para que el sort de 8 MB no vaya a disco.
--   Se mide SIN y CON work_mem = 256MB (sesión), se documenta.
-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- OPT-T3 (aceptada): reescritura de Top-50 pedidos.
-- El plan "antes" arma dos estructuras caras:
--   * Nested Loop pedido→cliente para TODOS los 166.857 pedidos
--     (con Memoize) y Merge Join con las 500.014 líneas, para
--     agregar después por (pe.id, c.nombre, c.apellido) con un
--     Incremental Sort de 12.645 grupos.
-- La reescritura agrega primero detalle_pedido por pedido_id
-- (los montos viven en la línea), filtra ENTREGADO/restantes en
-- el join y recién al final adjunta el cliente de los 50 elegidos.
-- Cambia Merge Join (pedido↔detalle) por Hash Join + agregación y
-- el Nested Loop pasa del 100% de pedidos a 50 filas.
-- Verificación de equivalencia del resultado: EXCEPT 0/0 (Parte 3).
-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- OPT-T4 (propuesta evaluada, se mide): índice covering sobre
-- producto (id) INCLUDE (categoria_id) para que el lookup por
-- línea ("Index Scan using producto_pkey ... Filter categoria_id
-- = ca.id", 133.542 ejecuciones, 400.626 buffers) deje de tocar
-- el heap. Hipótesis a validar en el plan "después".
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS ix_producto_cat_cover
    ON producto (id) INCLUDE (categoria_id);

-- ------------------------------------------------------------
-- OPT-T5 (intento A, RECHAZADO): mover HAVING count(*)>=5 dentro
-- de la CTE. Parecía equivalente, pero CAMBIÓ la semántica:
--   original  "frecuente" = cliente con >= 5 MESES con ventas
--             (count sobre filas (cliente, mes) del CTE)
--   intento A "frecuente" = cliente con >= 5 LÍNEAS en un mes
--             (count sobre la fila (mes) del CTE re-agrupada)
-- Resultado: 46.322 filas (original) vs 10.211 (intento A). Se
-- detectó comparando conteos y se DESCARTÓ. Documentado en
-- informe_analiticas_tp4.md y en la DUIA.
--
-- OPT-T5 (aceptada): materializar el agregado (cliente, mes) en
-- una MV. El running total es una métrica de dashboard que se
-- consulta de forma repetida; la MV evita re-scanear 500k líneas
-- y el doble materializado a disco del plan original. La
-- semántica es idéntica: (cliente, mes, facturado) es exactamente
-- la CTE del original; el filtro de frecuentes (>=5 meses) se
-- re-aplica sobre la MV en la consulta final.
-- ------------------------------------------------------------
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_fact_cliente_mes AS
SELECT pe.cliente_id,
       date_trunc('month', pe.fecha)           AS mes,
       SUM(d.cantidad * d.precio_unitario)     AS facturado
FROM pedido pe
JOIN detalle_pedido d ON d.pedido_id = pe.id
WHERE pe.estado = 'ENTREGADO'
GROUP BY pe.cliente_id, date_trunc('month', pe.fecha)
WITH DATA;

CREATE INDEX IF NOT EXISTS ix_mv_fact_cliente_mes
    ON mv_fact_cliente_mes (cliente_id, mes);

ANALYZE mv_fact_cliente_mes;