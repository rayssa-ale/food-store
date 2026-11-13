-- =============================================================================
-- SCRIPT: consultas_postgresql_corregidas.sql
-- MATERIA: Bases de Datos II — Tecnicatura Universitaria en Programación (UTN FRM)
-- UNIDAD 7: NoSQL y nuevas formas de almacenamiento | Food Store
-- =============================================================================
--
-- ORIGEN
-- Este archivo corrige los identificadores de `consultas_postgresql.sql`, que
-- se ejecutó contra la base de trabajo de U7 (catálogo con `usuario`,
-- `usuario_id`, `pedido.total` y estado 'TERMINADO'). Nada de eso existe en el
-- `schema.sql` publicado en este repositorio.
--
-- CATÁLOGO REAL (schema.sql)
--   cliente (id, nombre, apellido, email, telefono)
--   pedido  (id, fecha, cliente_id, forma_pago, estado)
--   estado_pedido = PENDIENTE | EN_PREPARACION | ENTREGADO | CANCELADO
--   pedido NO almacena `total`: es SUM(cantidad * precio_unitario).
--
-- RESULTADO ESPERADO SOBRE seed.sql (3 pedidos)
--   5.b: 1 fila  -> pedido 1, ENTREGADO, Dana Da Luz, 3250.00
--   5.c: 1 fila  -> pedido 1, 3250.00
-- =============================================================================

-- =============================================================================
-- CONSULTA 5.b (equivalente a MongoDB 4.b)
-- Filtrar pedidos por un estado del ENUM real. Se usa 'ENTREGADO' porque el
-- dominio publicado no tiene 'TERMINADO'.
-- =============================================================================
SELECT p.id AS pedido_id,
       p.fecha,
       p.estado,
       c.nombre || ' ' || c.apellido AS cliente,
       COALESCE(SUM(dp.cantidad * dp.precio_unitario), 0)::numeric(12,2) AS total
  FROM pedido p
  JOIN cliente c ON c.id = p.cliente_id
  LEFT JOIN detalle_pedido dp ON dp.pedido_id = p.id
 WHERE p.estado = 'ENTREGADO'
 GROUP BY p.id, p.fecha, p.estado, c.nombre, c.apellido
 ORDER BY p.id ASC;

-- Misma consulta parametrizada por estado (para comparar contra MongoDB con el
-- estado que exista en la carga; reemplazar el literal).
-- WHERE p.estado = 'EN_PREPARACION'

-- =============================================================================
-- CONSULTA 5.c (equivalente a MongoDB 4.c)
-- Pedidos que contienen el producto 1 en sus líneas. EXISTS evita la
-- duplicación de cabecera que produciría el JOIN con detalle_pedido.
-- =============================================================================
SELECT p.id AS pedido_id,
       p.fecha,
       p.estado,
       (SELECT COALESCE(SUM(d.cantidad * d.precio_unitario), 0)::numeric(12,2)
          FROM detalle_pedido d
         WHERE d.pedido_id = p.id) AS total
  FROM pedido p
 WHERE EXISTS (
        SELECT 1
          FROM detalle_pedido dp
         WHERE dp.pedido_id = p.id
           AND dp.producto_id = 1
       )
 ORDER BY p.id ASC;

-- Variante con JOIN + DISTINCT (mismo resultado, deduplicación explícita).
SELECT DISTINCT
       p.id AS pedido_id,
       p.fecha,
       p.estado,
       (SELECT COALESCE(SUM(d.cantidad * d.precio_unitario), 0)::numeric(12,2)
          FROM detalle_pedido d
         WHERE d.pedido_id = p.id) AS total
  FROM pedido p
  JOIN detalle_pedido dp ON dp.pedido_id = p.id
 WHERE dp.producto_id = 1
 ORDER BY p.id ASC;

-- =============================================================================
-- CONTRASTE CON MONGODB (misma semántica, distinto mecanismo)
--   PostgreSQL: reúne pedido con detalle_pedido y deduplica (EXISTS/DISTINCT).
--   MongoDB:    recorre `lineas` con el índice multikey y devuelve el documento
--               raíz sin reunión ni deduplicación.
-- La paridad de resultados se mantiene; los conteos dependen del conjunto de
-- datos: 10 pedidos en la base de trabajo de U7, 3 en el seed publicado.
-- =============================================================================
