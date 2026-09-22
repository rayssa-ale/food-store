-- ============================================================
-- FOOD STORE — TP3 Parte 4: equivalencia de consultas
-- Dos requisitos en lenguaje natural. A cada uno le corresponde
-- el SQL generado por IA (A) y una versión alternativa con la
-- MISMA semántica (B). La equivalencia se verifica comparando
-- los resultados con EXCEPT: ni (A EXCEPT B) ni (B EXCEPT A)
-- deben devolver filas. Correr sobre food_store_tp3.
-- ============================================================

-- ------------------------------------------------------------
-- ESPEC 1 (resumen / agregación)
-- "Listar cada categoría vigente con la cantidad de productos
--  vigentes que tiene, incluyendo las categorías que no tengan
--  ningún producto vigente (0), ordenado de mayor a menor
--  cantidad de productos."
--
-- (A) SQL generado por IA: LEFT JOIN + COUNT
-- ------------------------------------------------------------
WITH a AS (
    SELECT c.id, c.nombre, COUNT(p.id) AS cant
    FROM categoria c
    LEFT JOIN producto p ON p.categoria_id = c.id AND p.activo
    WHERE c.activo
    GROUP BY c.id, c.nombre
)
SELECT count(*) AS filas_de_esperado FROM a;  -- 3 (3 categorías vigentes, una con 0)

-- (B) versión alternativa: subconsulta escalar (misma semántica)
WITH b AS (
    SELECT c.id, c.nombre,
           (SELECT COUNT(*) FROM producto p
             WHERE p.categoria_id = c.id AND p.activo) AS cant
    FROM categoria c
    WHERE c.activo
)
SELECT count(*) AS filas_de_alternativo FROM b;

-- Verificación EXCEPT (ambas direcciones → deben ser 0)
SELECT count(*) AS espec1_a_menos_b
FROM (
    SELECT c.id, c.nombre, COUNT(p.id) AS cant
    FROM categoria c
    LEFT JOIN producto p ON p.categoria_id = c.id AND p.activo
    WHERE c.activo
    GROUP BY c.id, c.nombre
    EXCEPT
    SELECT c.id, c.nombre,
           (SELECT COUNT(*) FROM producto p
             WHERE p.categoria_id = c.id AND p.activo) AS cant
    FROM categoria c
    WHERE c.activo
) t;

SELECT count(*) AS espec1_b_menos_a
FROM (
    SELECT c.id, c.nombre,
           (SELECT COUNT(*) FROM producto p
             WHERE p.categoria_id = c.id AND p.activo) AS cant
    FROM categoria c
    WHERE c.activo
    EXCEPT
    SELECT c.id, c.nombre, COUNT(p.id) AS cant
    FROM categoria c
    LEFT JOIN producto p ON p.categoria_id = c.id AND p.activo
    WHERE c.activo
    GROUP BY c.id, c.nombre
) t;

-- ------------------------------------------------------------
-- ESPEC 2 (subconsulta / comparación con un agregado global)
-- "Clientes que hayan facturado más que el promedio facturado
--  por cliente, considerando solo pedidos ENTREGADO. Mostrar
--  id, apellido, nombre y total facturado, de mayor a menor."
-- Facturación por cliente = SUM(cantidad * precio_unitario) de
-- sus líneas (los montos derivan de las líneas, ver schema.sql).
--
-- (A) SQL generado por IA: GROUP BY + HAVING con subconsulta.
--     NOTA: dentro de la subconsulta el detalle se repite con un
--     alias PROPIO (d2); referenciar d.cantidad ahí correlaciona
--     contra el detalle del cliente externo y rompe la semántica.
-- ------------------------------------------------------------
WITH a AS (
    SELECT c.id, c.apellido, c.nombre,
           SUM(d.cantidad * d.precio_unitario) AS facturado
    FROM cliente c
    JOIN pedido pe ON pe.cliente_id = c.id AND pe.estado = 'ENTREGADO'
    JOIN detalle_pedido d ON d.pedido_id = pe.id
    GROUP BY c.id, c.apellido, c.nombre
    HAVING SUM(d.cantidad * d.precio_unitario) > (
        SELECT AVG(f)
        FROM (
            SELECT SUM(d2.cantidad * d2.precio_unitario) AS f
            FROM cliente c2
            JOIN pedido pe2 ON pe2.cliente_id = c2.id AND pe2.estado = 'ENTREGADO'
            JOIN detalle_pedido d2 ON d2.pedido_id = pe2.id
            GROUP BY c2.id
        ) s
    )
)
SELECT count(*) AS filas_de_esperado FROM a;

-- (B) versión alternativa: CTE con promedio explícito (misma semántica)
WITH totales AS (
    SELECT c.id, c.apellido, c.nombre,
           SUM(d.cantidad * d.precio_unitario) AS facturado
    FROM cliente c
    JOIN pedido pe ON pe.cliente_id = c.id AND pe.estado = 'ENTREGADO'
    JOIN detalle_pedido d ON d.pedido_id = pe.id
    GROUP BY c.id, c.apellido, c.nombre
), prom AS (
    SELECT AVG(facturado) AS p FROM totales
)
SELECT count(*) AS filas_de_alternativo
FROM totales t, prom
WHERE t.facturado > prom.p;

-- Verificación EXCEPT (ambas direcciones → deben ser 0)
SELECT count(*) AS espec2_a_menos_b
FROM (
    SELECT c.id, c.apellido, c.nombre,
           SUM(d.cantidad * d.precio_unitario) AS facturado
    FROM cliente c
    JOIN pedido pe ON pe.cliente_id = c.id AND pe.estado = 'ENTREGADO'
    JOIN detalle_pedido d ON d.pedido_id = pe.id
    GROUP BY c.id, c.apellido, c.nombre
    HAVING SUM(d.cantidad * d.precio_unitario) > (
        SELECT AVG(f)
        FROM (
            SELECT SUM(d2.cantidad * d2.precio_unitario) AS f
            FROM cliente c2
            JOIN pedido pe2 ON pe2.cliente_id = c2.id AND pe2.estado = 'ENTREGADO'
            JOIN detalle_pedido d2 ON d2.pedido_id = pe2.id
            GROUP BY c2.id
        ) s
    )
    EXCEPT
    SELECT t.id, t.apellido, t.nombre, t.facturado
    FROM (
        SELECT c.id, c.apellido, c.nombre,
               SUM(d.cantidad * d.precio_unitario) AS facturado
        FROM cliente c
        JOIN pedido pe ON pe.cliente_id = c.id AND pe.estado = 'ENTREGADO'
        JOIN detalle_pedido d ON d.pedido_id = pe.id
        GROUP BY c.id, c.apellido, c.nombre
    ) t
    CROSS JOIN (
        SELECT AVG(facturado) AS p
        FROM (
            SELECT c.id, c.apellido, c.nombre,
                   SUM(d.cantidad * d.precio_unitario) AS facturado
            FROM cliente c
            JOIN pedido pe ON pe.cliente_id = c.id AND pe.estado = 'ENTREGADO'
            JOIN detalle_pedido d ON d.pedido_id = pe.id
            GROUP BY c.id, c.apellido, c.nombre
        ) x
    ) prom
    WHERE t.facturado > prom.p
) t;

SELECT count(*) AS espec2_b_menos_a
FROM (
    SELECT t.id, t.apellido, t.nombre, t.facturado
    FROM (
        SELECT c.id, c.apellido, c.nombre,
               SUM(d.cantidad * d.precio_unitario) AS facturado
        FROM cliente c
        JOIN pedido pe ON pe.cliente_id = c.id AND pe.estado = 'ENTREGADO'
        JOIN detalle_pedido d ON d.pedido_id = pe.id
        GROUP BY c.id, c.apellido, c.nombre
    ) t
    CROSS JOIN (
        SELECT AVG(facturado) AS p
        FROM (
            SELECT c.id, c.apellido, c.nombre,
                   SUM(d.cantidad * d.precio_unitario) AS facturado
            FROM cliente c
            JOIN pedido pe ON pe.cliente_id = c.id AND pe.estado = 'ENTREGADO'
            JOIN detalle_pedido d ON d.pedido_id = pe.id
            GROUP BY c.id, c.apellido, c.nombre
        ) x
    ) prom
    WHERE t.facturado > prom.p
    EXCEPT
    SELECT c.id, c.apellido, c.nombre,
           SUM(d.cantidad * d.precio_unitario) AS facturado
    FROM cliente c
    JOIN pedido pe ON pe.cliente_id = c.id AND pe.estado = 'ENTREGADO'
    JOIN detalle_pedido d ON d.pedido_id = pe.id
    GROUP BY c.id, c.apellido, c.nombre
    HAVING SUM(d.cantidad * d.precio_unitario) > (
        SELECT AVG(f)
        FROM (
            SELECT SUM(d2.cantidad * d2.precio_unitario) AS f
            FROM cliente c2
            JOIN pedido pe2 ON pe2.cliente_id = c2.id AND pe2.estado = 'ENTREGADO'
            JOIN detalle_pedido d2 ON d2.pedido_id = pe2.id
            GROUP BY c2.id
        ) s
    )
) t;