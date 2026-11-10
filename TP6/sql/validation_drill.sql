-- =============================================================================
-- SCRIPT: validation_drill.sql
-- PROYECTO: FoodStore (PostgreSQL 18)
-- MATERIA: Bases de Datos II - Tecnicatura Universitaria en Programación
-- UNIDAD 6: Mantenimiento, respaldo y recuperación
--
-- OBJETIVO: Validación de integridad y consistencia post-restauración en
--           la base descartable 'foodstore_restore_test'.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- CONTROL 1: Conteo de filas en tablas maestras y transaccionales
-- Verifica que las entidades principales hayan sido restauradas íntegramente.
-- -----------------------------------------------------------------------------
SELECT 'categoria' AS tabla, COUNT(*) AS filas FROM categoria
UNION ALL SELECT 'usuario', COUNT(*) AS filas FROM usuario
UNION ALL SELECT 'producto', COUNT(*) AS filas FROM producto
UNION ALL SELECT 'pedido', COUNT(*) AS filas FROM pedido
UNION ALL SELECT 'detalle_pedido', COUNT(*) AS filas FROM detalle_pedido;


-- -----------------------------------------------------------------------------
-- CONTROL 2: Regla de integridad de catálogo de productos
-- Condición de éxito: Debe devolver 0 filas con precio < 0 o stock < 0.
-- -----------------------------------------------------------------------------
SELECT COUNT(*) AS productos_invalidos
FROM producto
WHERE precio < 0 OR stock < 0;


-- -----------------------------------------------------------------------------
-- CONTROL 3: Regla de integridad de detalles de pedidos
-- Condición de éxito: Debe devolver 0 filas con cantidad <= 0 o precio_unitario < 0.
-- -----------------------------------------------------------------------------
SELECT COUNT(*) AS detalles_invalidos
FROM detalle_pedido
WHERE cantidad <= 0 OR precio_unitario < 0;
