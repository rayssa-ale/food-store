-- ============================================================
-- FOOD STORE — TP3 Parte 2: optimizaciones propuestas por IA
-- Cada propuesta ataca un NODO concreto de un plan real medido
-- (docs/planes/*_antes.txt). Solo se aplican las que pueden
-- explicarse frente al plan; el resto se documenta en la tabla
-- comparativa. Aplicar sobre la copia food_store_tp3 y volver a
-- medir con EXPLAIN (ANALYZE, BUFFERS).
-- ============================================================

-- ------------------------------------------------------------
-- OPT-1: producto (categoria_id, precio) parcial sobre activos
-- Ataca a Q1_carta y Q6_competencia:
--   Plan actual = Bitmap Index Scan sobre idx_producto_categoria
--   (columna única) + Bitmap Heap Scan que RE-FILTRA el rango de
--   precio sobre ~16.700 filas + sort manual.
--   Con (categoria_id, precio) el índice resuelve el filtro de
--   precio y, en Q6, el ORDER BY precio/limit queda indexado.
--   Esperado: menos filas leídas y sin filtro de rechequeo.
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS ix_producto_cat_precio
    ON producto (categoria_id, precio)
    WHERE activo = TRUE;

-- ------------------------------------------------------------
-- OPT-2: detalle_pedido (producto_id) INCLUDE (cantidad)
-- Ataca a Q3_top_productos:
--   Plan actual = Seq Scan del heap de detalle_pedido (500.014
--   filas) + HashAggregate por producto. La consulta SOLO usa
--   producto_id y cantidad.
--   Con un índice que incluye cantidad, el agregado lee un
--   Index-Only Scan (sin tocar el heap). Esperado: baja I/O y
--   tiempo del scan, el agregado queda como costo remanente.
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS ix_detalle_prod_cant
    ON detalle_pedido (producto_id) INCLUDE (cantidad);

-- ------------------------------------------------------------
-- OPT-3: pedido (estado)
-- Ataca a Q4_facturacion_clientes:
--   Plan actual = Seq Scan de pedido filtrando estado='ENTREGADO'
--   (Rows Removed by Filter ~50%). Hipótesis: al indexar estado
--   el scan se reduce a las filas cobradas.
--   ADVERTENCIA: la hipótesis fue que este era el cuello de
--   botella; el plan real muestra que el costo dominante es el
--   agregado/hash join sobre detalle (500k). Se mide y se
--   documenta el resultado real.
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS ix_pedido_estado ON pedido (estado);