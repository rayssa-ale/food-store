-- =============================================================================
-- SCRIPT: consultas_postgresql.sql
-- MATERIA: Bases de Datos II — Tecnicatura Universitaria en Programación (UTN FRM)
-- UNIDAD 7: NoSQL y nuevas formas de almacenamiento | Food Store
-- =============================================================================
-- 
-- OBJETIVO:
-- Ejecutar las consultas SQL equivalentes a las consignas 4.b y 4.c de MongoDB
-- sobre la base de datos relacional Food Store en PostgreSQL.
-- 
-- NOTA DE COMPATIBILIDAD DE CATÁLOGO:
-- Conforme al catálogo físico validado de Food Store (schema.sql / Unidad 6),
-- la entidad de clientes se denomina 'usuario' (con usuario_id en 'pedido').
-- =============================================================================

-- =============================================================================
-- CONSULTA 5.b (Equivalente a MongoDB 4.b):
-- Filtrar pedidos por un estado que exista en los datos migrados ('TERMINADO')
-- =============================================================================

-- Variante 1: Esquema con columna 'total' precalculada en tabla 'pedido'
SELECT 
    p.id AS pedido_id,
    p.fecha,
    p.estado,
    u.nombre || ' ' || u.apellido AS cliente,
    p.total
FROM pedido p
JOIN usuario u ON p.usuario_id = u.id
WHERE p.estado = 'TERMINADO'
ORDER BY p.id ASC;

-- Variante 2: Esquema estrictamente normalizado en 3FN (cálculo dinámico del total)
SELECT 
    p.id AS pedido_id,
    p.fecha,
    p.estado,
    u.nombre || ' ' || u.apellido AS cliente,
    COALESCE(SUM(dp.cantidad * dp.precio_unitario), 0)::numeric(12,2) AS total
FROM pedido p
JOIN usuario u ON p.usuario_id = u.id
LEFT JOIN detalle_pedido dp ON p.id = dp.pedido_id
WHERE p.estado = 'TERMINADO'
GROUP BY p.id, p.fecha, p.estado, u.nombre, u.apellido
ORDER BY p.id ASC;

/*
 RESULTADO ESPERADO EN POSTGRESQL (7 filas):
  pedido_id |   fecha    |  estado   |      cliente       |  total   
 -----------+------------+-----------+--------------------+----------
          2 | 2026-06-12 | TERMINADO | María López        |  5250.00
          3 | 2026-06-20 | TERMINADO | Juan Pérez         |  3800.00
          4 | 2026-07-02 | TERMINADO | Carlos Díaz        | 12600.00
          6 | 2026-07-18 | TERMINADO | María López        |  6300.00
          7 | 2026-07-25 | TERMINADO | Juan Pérez         |  9400.00
          9 | 2026-08-11 | TERMINADO | Lucía Fernández    | 15500.00
         10 | 2026-08-19 | TERMINADO | María López        | 24100.00
*/


-- =============================================================================
-- CONSULTA 5.c (Equivalente a MongoDB 4.c):
-- Buscar pedidos que contengan un producto determinado (producto_id = 1, 'Muzzarella')
-- =============================================================================

-- Enfoque A: Mediante INNER JOIN y DISTINCT para evitar duplicidad de pedidos
SELECT DISTINCT
    p.id AS pedido_id,
    p.fecha,
    p.estado,
    p.total
FROM pedido p
JOIN detalle_pedido dp ON p.id = dp.pedido_id
WHERE dp.producto_id = 1
ORDER BY p.id ASC;

-- Enfoque B: Mediante operador semi-join EXISTS (Semántica relacional idéntica a MongoDB)
SELECT 
    p.id AS pedido_id,
    p.fecha,
    p.estado,
    p.total
FROM pedido p
WHERE EXISTS (
    SELECT 1 
    FROM detalle_pedido dp 
    WHERE dp.pedido_id = p.id 
      AND dp.producto_id = 1
)
ORDER BY p.id ASC;

/*
 RESULTADO ESPERADO EN POSTGRESQL (4 filas):
  pedido_id |   fecha    |   estado   |  total   
 -----------+------------+------------+----------
          1 | 2026-06-05 | CONFIRMADO |  9100.00
          4 | 2026-07-02 | TERMINADO  | 12600.00
          7 | 2026-07-25 | TERMINADO  |  9400.00
         10 | 2026-08-19 | TERMINADO  | 24100.00

 CONTRASTE TÉCNICO DE EJECUCIÓN (SQL vs NoSQL):
 - En PostgreSQL: Para responder a la consulta (c), el motor debe realizar un
   escaneo de índice o tabla sobre 'detalle_pedido', filtrar por producto_id = 1
   y luego realizar una operación de reunión (Hash Join o Nested Loop) contra 'pedido',
   requiriendo DISTINCT o EXISTS para eliminar duplicados de cabecera.
 - En MongoDB: La consulta db.pedidos.find({ "lineas.producto_id": 1 }) se resuelve
   directamente accediendo a los documentos de la colección 'pedidos' mediante el
   índice multikey 'idx_multikey_lineas_producto', recuperando el pedido completo
   en un único acceso sin joins ni deduplicaciones adicionales.
*/
