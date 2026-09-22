-- ============================================================
-- FOOD STORE — TP4 Parte 1: versiones "después" de las analíticas
-- (mismas respuestas, plan optimizado). Se miden contra las
-- originales de queries_tp4.sql. Equivalencia formal en Parte 3.
-- ============================================================

-- T1_opt — reporte sobre la MV materializada (39 filas).
SELECT categoria, to_char(mes, 'YYYY-MM') AS mes, facturado, lineas
FROM mv_ventas_categoria_mes
ORDER BY mes, categoria;

-- T2_opt — igual SQL que el original; la diferencia es el
-- work_mem de la sesión (no se reescribe, se re-mide con
-- SET work_mem='256MB' ANTES de correrla).
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

-- T3_opt — reescritura: agregar primero, adjuntar cliente al final.
WITH imp AS (
    SELECT d.pedido_id,
           COUNT(d.id)                         AS lineas,
           SUM(d.cantidad * d.precio_unitario) AS importe
    FROM detalle_pedido d
    JOIN pedido pe ON pe.id = d.pedido_id AND pe.estado <> 'CANCELADO'
    GROUP BY d.pedido_id
    ORDER BY importe DESC
    LIMIT 50
)
SELECT imp.pedido_id, c.nombre, c.apellido, imp.lineas, imp.importe
FROM imp
JOIN pedido pe  ON pe.id = imp.pedido_id
JOIN cliente c  ON c.id = pe.cliente_id
ORDER BY imp.importe DESC;

-- T4_opt — igual SQL (el mismo query); la diferencia son los
-- índices covering creados en optimizaciones_tp4.sql.
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

-- T5_opt — reescritura semánticamente EQUIVALENTE sobre la MV de
-- (cliente, mes). El filtro de frecuentes (>= 5 meses) se aplica
-- sobre la misma MV: mismas columnas y definición que el original.
SELECT c.id, c.nombre || ' ' || c.apellido AS nombre,
       to_char(m.mes, 'YYYY-MM') AS mes,
       m.facturado,
       SUM(m.facturado) OVER (PARTITION BY c.id ORDER BY m.mes) AS acumulado
FROM mv_fact_cliente_mes m
JOIN cliente c ON c.id = m.cliente_id
WHERE c.id IN (
    SELECT cliente_id FROM mv_fact_cliente_mes
    GROUP BY cliente_id HAVING COUNT(*) >= 5
)
ORDER BY c.id, m.mes;