# Informe de laboratorio — Optimización con EXPLAIN ANALYZE (TP3, Parte 2)

**Materia:** Base de Datos II — UTN | **Proyecto:** Food Store
**Base:** `food_store_tp3` (copia, sin triggers del TP2) · **Volumen:** 50.006 productos, 20.003 clientes, 200.003 pedidos, 500.014 líneas

## Metodología (flujo profesional de la cátedra)

1. Medir antes con `EXPLAIN (ANALYZE, BUFFERS)` **en caliente** (2.ª corrida) y guardar el plan completo en `docs/planes/*_antes.txt`.
2. Pasar el plan real a la IA (OpenCode) → propone índices/reescrituras justificando cada uno por el nodo que ataca.
3. Leer cada propuesta línea por línea; solo se acepta lo que se puede explicar frente al plan.
4. Aplicar sobre la copia, `ANALYZE`, volver a medir → `docs/planes/*_despues.txt`.
5. Completar la tabla comparativa. **Lo que no mejora se documenta, no se silencia.**

## 2.2 Tabla de resultados (Execution Time real, ms, en caliente)

| Consulta | Plan antes (nodo, cost est., t. real) | Cambio aplicado | Plan después (nodo, cost est., t. real) | Mejora |
|---|---|---|---|---|
| **Q6_competencia** (productos cat. 2, precio 600–3000, activos, orden por precio) | Bitmap Index Scan `idx_producto_categoria` (col. única) + Bitmap Heap recheck de precio + Sort. Cost 0.00..289.41; **14.242 ms** | **OPT-1** `CREATE INDEX ix_producto_cat_precio ON producto (categoria_id, precio) WHERE activo` | Index Scan `ix_producto_cat_precio`; el rango pasa a `Index Cond`, pre-sorted por precio. Cost 1.33..44.40; **0.338 ms** | **×42** ✔ |
| **Q1_carta** (Pizzas, precio 700–4500, orden por nombre) | Bitmap en `idx_producto_categoria` (16.669 filas) + Heap con recheck precio (Rows Removed by Filter 2.577) + Sort nombre. **30.645 ms** | OPT-1 (mismo índice; esperado: atacar el recheck). El optimizador **no lo eligió**: siguió con el bitmap + recheck (plan casi idéntico). **25.703 ms** | **No sustancial (≈1,19×)** — el índice nuevo sale más caro para este plan y el Sort por `nombre` domina. Se documenta. |
| **Q3_top_productos** (top 10 por cantidad) | Seq Scan `detalle_pedido` (500.014 filas) + Hash Join + HashAggregate (Group Key p.id, 3.865 kB) + Sort top-N. **553.600 ms** | **OPT-2** covering `(producto_id) INCLUDE (cantidad)` (Index-Only Scan) | El planner **desestimó** el covering (Seq Scan igual; el costo del agregado domina). **508.222 ms** | **Marginal (≈1,09×)** — el HashAggregate sobre 500k filas es el cuello real. Se documenta. |
| **Q4_facturacion_clientes** (suma por cliente, solo ENTREGADO) | Parallel Seq Scan `pedido` con Filter estado (Rows Removed by Filter ~49.977 c/worker, 50%) + HashAggregate en 5 batches con **spill a disco (224 kB)** + Gather. **431.486 ms** | **OPT-3** `CREATE INDEX ix_pedido_estado ON pedido (estado)` — hipótesis: recortar el scan de pedido | El nodo dominante era el agregado/hash sobre 500k líneas, no el filtro de estado: el plan no cambió. **491.502 ms** | **No mejora** — la hipótesis era incorrecta; se descarta y documenta. |

> Q2_historial_cliente (0.398 ms) y Q5 no se tocaron: ya resolvían con índices existentes (uq_detalle_pedido_producto / idx_pedido_cliente).

## Criterio de aceptación (aplicado)

- **Se aceptó** OPT-1 → explicable por el plan (el rango de precio se filtraba en el heap tras el bitmap; al llevarlo al `Index Cond` se acorta el recorrido y el orden queda pre-sorted). Verificado: ×42.
- **Se probó y documentó** OPT-2 y OPT-3 → se explicó la hipótesis, se midió el resultado real y se registró por qué no cambió el plan (no se descartaron en silencio).
- **Rechazo explícito:** ninguna propuesta se aplicó "porque la IA lo dijo"; cada una tenía un nodo concreto que justificar y una medición que la confirmara o rebatiera.

Planes completos (verbatim): `docs/planes/*_antes.txt` y `docs/planes/*_despues.txt`.