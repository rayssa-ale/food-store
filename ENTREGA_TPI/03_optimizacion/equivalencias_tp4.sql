-- ============================================================
-- FOOD STORE â€” TP4 Parte 3: equivalencia de consultas
-- Dos especificaciones precisas (una con funciÃ³n de ventana RANK
-- y otra con subconsulta correlacionada). Cada una se genera en
-- dos versiones de estructura distinta y se verifica con EXCEPT
-- en ambas direcciones (deben dar 0 filas).
-- Correr sobre food_store_tp3.
-- ============================================================

-- ------------------------------------------------------------
-- ESPEC (a) â€” RANKING con funciÃ³n de ventana
-- "Para cada cliente con al menos un pedido ENTREGADO, mostrar
--  apellido, nombre, email, total gastado (suma de cantidad por
--  precio_unitario de las lÃ­neas de sus pedidos ENTREGADO) y su
--  puesto en un ranking de mayor a menor gasto. Los que empatan
--  en gasto comparten puesto y los siguientes quedan saltados
--  (RANK clÃ¡sico). Orden final por puesto y por id ascendente.
--  No usar SELECT *."
--
-- (A) generada por IA: RANK() OVER (ORDER BY total DESC)
-- (B) alternativa (misma semÃ¡ntica): puesto = 1 + cantidad de
--     totales distintos mayores (definiciÃ³n clÃ¡sica de RANK sin
--     ventana).
-- ------------------------------------------------------------
WITH totales AS (
    SELECT c.id, c.apellido, c.nombre, c.email,
           SUM(d.cantidad * d.precio_unitario) AS total
    FROM cliente c
    JOIN pedido pe       ON pe.cliente_id = c.id AND pe.estado = 'ENTREGADO'
    JOIN detalle_pedido d ON d.pedido_id = pe.id
    GROUP BY c.id, c.apellido, c.nombre, c.email
)
SELECT (SELECT count(*) FROM totales) AS clientes,
       (SELECT count(*) FROM (
            SELECT apellido, nombre, email, total,
                   RANK() OVER (ORDER BY total DESC) AS puesto FROM totales
        ) x) AS filas_A_windowing,
       (SELECT count(*) FROM (
            SELECT apellido, nombre, email, total,
                   1 + (SELECT COUNT(*)
                        FROM totales t2 WHERE t2.total > t.total) AS puesto
            FROM totales t
        ) x) AS filas_B_correlacionada;

-- VerificaciÃ³n EXCEPT (ambas direcciones -> 0)
SELECT count(*) AS especA_a_menos_b
FROM (
    (WITH totales AS (
        SELECT c.id, c.apellido, c.nombre, c.email,
               SUM(d.cantidad * d.precio_unitario) AS total
        FROM cliente c
        JOIN pedido pe       ON pe.cliente_id = c.id AND pe.estado = 'ENTREGADO'
        JOIN detalle_pedido d ON d.pedido_id = pe.id
        GROUP BY c.id, c.apellido, c.nombre, c.email)
     SELECT apellido, nombre, email, total,
            RANK() OVER (ORDER BY total DESC) AS puesto
     FROM totales)
    EXCEPT
    (WITH totales AS (
        SELECT c.id, c.apellido, c.nombre, c.email,
               SUM(d.cantidad * d.precio_unitario) AS total
        FROM cliente c
        JOIN pedido pe       ON pe.cliente_id = c.id AND pe.estado = 'ENTREGADO'
        JOIN detalle_pedido d ON d.pedido_id = pe.id
        GROUP BY c.id, c.apellido, c.nombre, c.email)
     SELECT apellido, nombre, email, total,
            1 + (SELECT COUNT(*)
                 FROM totales t2 WHERE t2.total > t.total) AS puesto
     FROM totales t)
) t;

SELECT count(*) AS especA_b_menos_a
FROM (
    (WITH totales AS (
        SELECT c.id, c.apellido, c.nombre, c.email,
               SUM(d.cantidad * d.precio_unitario) AS total
        FROM cliente c
        JOIN pedido pe       ON pe.cliente_id = c.id AND pe.estado = 'ENTREGADO'
        JOIN detalle_pedido d ON d.pedido_id = pe.id
        GROUP BY c.id, c.apellido, c.nombre, c.email)
     SELECT apellido, nombre, email, total,
            1 + (SELECT COUNT(*)
                 FROM totales t2 WHERE t2.total > t.total) AS puesto
     FROM totales t)
    EXCEPT
    (WITH totales AS (
        SELECT c.id, c.apellido, c.nombre, c.email,
               SUM(d.cantidad * d.precio_unitario) AS total
        FROM cliente c
        JOIN pedido pe       ON pe.cliente_id = c.id AND pe.estado = 'ENTREGADO'
        JOIN detalle_pedido d ON d.pedido_id = pe.id
        GROUP BY c.id, c.apellido, c.nombre, c.email)
     SELECT apellido, nombre, email, total,
            RANK() OVER (ORDER BY total DESC) AS puesto
     FROM totales)
) t;

-- ------------------------------------------------------------
-- ESPEC (b) â€” SUBCONSULTA CORRELACIONADA
-- "Para cada producto vigente, mostrar id, nombre, precio y un
--  indicador SÃ/NO de si su precio es MAYOR que el promedio de
--  los precios de los productos vigentes de su propia categorÃ­a."
--
-- (A) generada por IA: subconsulta escalar correlacionada.
-- (B) alternativa (misma semÃ¡ntica): funciÃ³n de ventana AVG
--     particionada por categorÃ­a (el mismo promedio por categorÃ­a).
-- ------------------------------------------------------------
WITH a AS (
    SELECT p.id, p.nombre, p.precio,
           CASE WHEN p.precio > (SELECT AVG(p2.precio)
                                 FROM producto p2
                                 WHERE p2.categoria_id = p.categoria_id
                                   AND p2.activo)
                THEN 'SI' ELSE 'NO' END AS sobre_promedio
    FROM producto p
    WHERE p.activo
), b AS (
    SELECT id, nombre, precio,
           CASE WHEN precio > AVG(precio) OVER (PARTITION BY categoria_id)
                THEN 'SI' ELSE 'NO' END AS sobre_promedio
    FROM producto p
    WHERE activo
)
SELECT (SELECT count(*) FROM a) AS filas_A,
       (SELECT count(*) FROM a WHERE sobre_promedio = 'SI') AS si_A,
       (SELECT count(*) FROM b) AS filas_B,
       (SELECT count(*) FROM b WHERE sobre_promedio = 'SI') AS si_B;

-- VerificaciÃ³n EXCEPT (ambas direcciones -> 0)
SELECT count(*) AS especB_a_menos_b
FROM (
    (SELECT p.id, p.nombre, p.precio,
            CASE WHEN p.precio > (SELECT AVG(p2.precio)
                                  FROM producto p2
                                  WHERE p2.categoria_id = p.categoria_id AND p2.activo)
                 THEN 'SI' ELSE 'NO' END AS sobre_promedio
     FROM producto p
     WHERE p.activo)
    EXCEPT
    (SELECT id, nombre, precio,
            CASE WHEN precio > AVG(precio) OVER (PARTITION BY categoria_id)
                 THEN 'SI' ELSE 'NO' END AS sobre_promedio
     FROM producto p
     WHERE activo)
) t;

SELECT count(*) AS especB_b_menos_a
FROM (
    (SELECT id, nombre, precio,
            CASE WHEN precio > AVG(precio) OVER (PARTITION BY categoria_id)
                 THEN 'SI' ELSE 'NO' END AS sobre_promedio
     FROM producto p
     WHERE activo)
    EXCEPT
    (SELECT p.id, p.nombre, p.precio,
            CASE WHEN p.precio > (SELECT AVG(p2.precio)
                                  FROM producto p2
                                  WHERE p2.categoria_id = p.categoria_id AND p2.activo)
                 THEN 'SI' ELSE 'NO' END AS sobre_promedio
     FROM producto p
     WHERE p.activo)
) t;