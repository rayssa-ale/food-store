# FOOD STORE — TP5: informe de mediciones

**Base de Datos II — UTN · Equipo G · 22/09/2026**
Base de trabajo: copia **food_store_tp5** (clonada de food_store_tp3 vía
`createdb -T`; 200.003 pedidos, 500.014 líneas, 50.006 productos, 20.003
clientes, respaldo previo en `respaldos/food_store_tp3_20260922_antes_tp5.sql`).
Servidor en caliente, PostgreSQL 18. Mediciones: `EXPLAIN (ANALYZE, BUFFERS)`,
3 corridas, se reporta la mejor. Los planes textuales completos están en
`docs/planes5/`.

Flujo: spec → Kiro → `specs/` · generación → OpenCode → `sql/*.sql` ·
verificación → motor (EXCEPT / EXPLAIN) · versionado → commits por pieza.

---

## Parte A — Plan de indexado asistido por IA

### A.1 Consultas frecuentes y planes antes/después

| Consulta (frecuencia) | Nodo dominante ANTES | Nodo dominante DESPUÉS | Tiempo ANTES | Tiempo DESPUÉS | Mejora |
|---|---|---|---|---|---|
| **A1** pedidos del mes (`pedido`, mensual) | `Seq Scan` 200k + filtro + `Sort` 1556 kB | `Bitmap Index Scan ix_pedido_fecha_estado` (16.809) + `Sort` | 18.8 ms | 11.5 ms | **×1.6** |
| **A2** productos a reponer (`producto`, diario) | `Seq Scan` 50k + filtro + `Sort` | `Index Scan ix_producto_stock_reposicion` (parcial) + `Incremental Sort` presorted (226 filas→100) | 10.4 ms | **0.34 ms** | **×30.4** |
| **A3** cliente por apellido (`cliente`, decenas/día) | `Seq Scan` 20k + `Sort` | `Bitmap Index Scan ix_cliente_apellido_nombre` (1.111) + top-N heapsort | 2.75 ms | 1.40 ms | **×2.0** |

Consultas en `sql/queries_tp5.sql`. Planes en `docs/planes5/{A1_reporte_mensual,A2_stock_reposicion,A3_cliente_apellido}_{antes,despues}.txt`.

### A.2 Índices aceptados (`sql/indices.sql`)

1. **`ix_pedido_fecha_estado (fecha, estado)`** — compuesto; `fecha` líder
   (selectiva, ~8 % del mes) convierte el rango en entrada de árbol y sirve a
   la variante `estado = 'ENTREGADO'` (dashboard mensual). Build: 439 ms.
2. **`ix_producto_stock_reposicion (stock) WHERE stock < 50`** — **índice
   parcial**: indexa solo las 12,4 k filas que interesan (de 50 k): menor
   espacio y mantenimiento. Build: 36 ms. El `Incremental Sort` presorted lee
   solo 226 filas para entregar 100.
3. **`ix_cliente_apellido_nombre (apellido text_pattern_ops, nombre text_pattern_ops)`** —
   clase de operador `text_pattern_ops` para explotar `LIKE 'prefijo%'` con
   B-tree (collations no-C); compuesto presorted para la paginación. Build: 50 ms.

### A.3 Índice descartado (sobreindexación) — D1

Propuesta de la IA: `CREATE INDEX idx_detalle_cantidad ON detalle_pedido (cantidad)`.

Se comprobó **empíricamente** en transacción reversible
(`docs/planes5/D1_q3_top_unidades_con_indice.txt`): con el índice creado, el
plan de Q3 (top 10 por unidades) **sigue siendo `Seq Scan` sobre las 512 k
líneas** + HashAggregate (316 ms). Es una agregación de tabla completa: el
índice jamás aparece y solo pagaría mantenimiento en cada INSERT. **Descartado.

### A.4 Índice descartado (redundante) — D2

Propuesta: `idx_pedido_cliente_estado (cliente_id, estado)`. Redundante con
`idx_pedido_cliente (cliente_id)`: ~10 pedidos por cliente (200 k / 20 k), el
filtro extra por `estado` (cardinalidad 4) no cambia el plan de Q2 y sí suma
costo de escritura. **Descartado** (ver `specs/descartado_pedido_cliente_estado.md`).

### A.5 Costo de los índices sobre la escritura

Carga de **6.000 pedidos + 6.000 líneas** (misma forma antes/después;
`sql/prueba_escritura_antes.sql` y `prueba_escritura_despues.sql`):

| Operación | ANTES | DESPUÉS | Δ |
|---|---|---|---|
| INSERT 6.000 × `pedido` (mantiene `ix_pedido_fecha_estado`) | 234.5 ms | 237.8 ms | **+1.4 %** |
| INSERT 6.000 × `detalle_pedido` (los índices nuevos NO están sobre esta tabla) | 416.8 ms | 304.7 ms | dentro del ruido individual |

Lectura honesta: el único índice nuevo que se paga en cada escritura de la
prueba es el compuesto de `pedido` (+1,4 %, aceptable frente a ×1.6–30 en
lectura); `detalle_pedido` no cambia porque ningún índice nuevo lo toca.

---

## Parte B — Vistas para los reportes (`sql/views.sql`)

| Vista | Exposición | Filas | vs consulta manual (EXCEPT) |
|---|---|---|---|
| `v_reporte_productos_vigentes` | producto vigente + nombre de categoría (oculta `created_at`) | 50.006 | **0 / 0** |
| `v_reporte_pedidos_cliente` | pedidos con datos del cliente (oculta `telefono`, `created_at`) | 212.003 | **0 / 0** |
| `v_reporte_detalle_pedido` | línea + nombre de producto + `importe` derivado (R4) | 512.014 | **0 / 0** |
| `v_cliente_contacto` (SEGURIDAD) | cliente **sin `telefono`** (id, nombre, apellido, email) | 20.003 | **0 / 0** |

Verificación en `sql/verificacion_views.sql`: filas idénticas + `EXCEPT` en
ambas direcciones = 0 para las 4 vistas, y comprobación de que `telefono` no
es columna de `v_cliente_contacto` (0 columnas en `information_schema`).

**Adaptación de seguridad documentada:** el enunciado pide "usuario sin
contraseña"; el modelo local no tiene tabla `usuario` ni columna
`contraseña` (el alta es `cliente`, R6). El dato personal que oculta la vista
de seguridad es `telefono`: `GRANT SELECT ON v_cliente_contacto` sin acceso a
la tabla base. Ver `specs/vista_cliente_contacto_seguridad.md`.

---

## Parte C — Vista materializada (`sql/materializadas.sql`)

Reporte costoso elegido: **facturación por categoría, mes y forma de pago**
(117 filas), que re-escanea 500 k líneas por corrida.

| Método | EXPLAIN (best-of 3) | Build |
|---|---|---|
| Consulta original (4 tables, agregado) | **905.8 ms** | — |
| `mv_facturacion_categoria_mes_pago` (WITH DATA) | **0.022 ms** | 908 ms |

**Mejora: ×41.000.** La MV tiene índice **ÚNICO**
`uq_mv_facturacion_cat_mes_pago (categoria, mes, forma_pago)`, requisito para
`REFRESH MATERIALIZED VIEW CONCURRENTLY` (probado, funciona) y uno de soporte
por `mes`. Equivalencia MV ↔ consulta original: **EXCEPT 0 / 0**
(`sql/verificacion_materializada.sql`).

**Frecuencia de refresco sugerida:** una vez al día, en el cierre de jornada
(job nocturno, p. ej. 00:10), porque el reporte es de gerencia diaria y los
pedidos ENTREGADO se cierran a lo largo del día.

**Qué implica para el usuario el dato "viejo":** entre refrescos la MV no
refleja pedidos que acaban de pasar a ENTREGADO (ni correcciones de líneas
sobre las que ya se facturó). Para este reporte es aceptable: la diferencia
máxima de frescura es < 24 h y el costo de refresco en vivo (908 ms de
reescritura) no se justifica en horario operativo. De cambiar el uso (p. ej.
un dashboard de caja en tiempo real), se subiría la frecuencia con
`REFRESH CONCURRENTLY` sin bloquear lecturas.