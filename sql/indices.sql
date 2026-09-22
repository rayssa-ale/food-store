-- ============================================================
-- FOOD STORE — TP5 Parte A: indices.sql
-- Plan de indexado asistido por IA, aceptado tras medición.
-- Especificaciones en specs/ (entregable Kiro). Base: food_store_tp5.
-- No modifica schema.sql (los índices viven fuera del DDL base).
-- Dos propuestas de la IA se DESCARTARON (ver specs/descartado_*).
-- ============================================================

-- ------------------------------------------------------------
-- I1 — ix_pedido_fecha_estado
-- Reporte de gerencia "pedidos del mes" (queries_tp5.sql A1).
-- Sin índice con prefijo fecha: hoy hace Seq Scan + Sort (20 ms).
-- Compuesto: fecha líder (selectiva) + estado (variante ENTREGADO).
-- Deja el ORDER BY fecha presorted (sin Sort).
-- ------------------------------------------------------------
CREATE INDEX ix_pedido_fecha_estado ON pedido (fecha, estado);

-- ------------------------------------------------------------
-- I2 — ix_producto_stock_reposicion
-- Reporte operativo "productos a reponer" (queries_tp5.sql A2).
-- ÍNDICE PARCIAL: solo indexa las ~12,4 k filas con stock < 50 de
-- las 50 k (condición de índice parcial: menos espacio y menos
-- mantenimiento que indexar toda la columna stock).
-- ------------------------------------------------------------
CREATE INDEX ix_producto_stock_reposicion ON producto (stock)
    WHERE stock < 50;

-- ------------------------------------------------------------
-- I3 — ix_cliente_apellido_nombre
-- Búsqueda de clientes por apellido en el panel (queries_tp5.sql A3).
-- text_pattern_ops habilita el rango de LIKE 'prefijo%' con B-tree
-- cuando el collation por defecto no es C; el compuesto deja el
-- ORDER BY apellido, nombre presorted.
-- ------------------------------------------------------------
CREATE INDEX ix_cliente_apellido_nombre ON cliente
    (apellido text_pattern_ops, nombre text_pattern_ops);

-- Estadística actualizada para que el planificador decida con datos
-- frescos (los CREATE INDEX son sobre datos existentes de la copia).
ANALYZE pedido;
ANALYZE producto;
ANALYZE cliente;