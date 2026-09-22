# duia.md — Declaración de uso de IA y bitácora (TP5)

**Materia:** Base de Datos II — UTN · **Proyecto:** Food Store · **Fecha:** 22/09/2026
**Herramientas:** **Kiro** (especificaciones; los archivos quedaron en `specs/` y son el
entregable de especificación) y **OpenCode** (agente de codificación en terminal, modelo
*big-pickle) para generar el SQL a partir de cada spec. **Git/GitHub** para el historial.

Regla de cátedra respetada: la IA **propone** y escribe; el **motor y los números
deciden** (EXPLAIN ANALYZE / EXCEPT); el humano **lee línea por línea y justifica** cada
decisión antes de versionarla.

---

## 1. Plan de indexado (Parte A)

### 1.1 Índice ix_pedido_fecha_estado
- **Spec (Kiro):** `specs/indice_pedido_fecha_estado.md` — reporte mensual de pedidos,
  columnas `fecha` + `estado`, criterio: pasar de Seq Scan a Index/Bitmap.
- **Propuesta de la IA (OpenCode):** `CREATE INDEX ... ON pedido (fecha, estado);`.
- **Verificación en el motor:** antes `Seq Scan` 200 k + Sort (18.8 ms) → después
  `Bitmap Index Scan` sobre el índice (16.809 filas, 11.5 ms, **×1.6**).
- **Decisión:** aceptado sin modificaciones. El `Sort` persiste porque el planificador
  eligió Bitmap (rango del 8 %) en vez de Index Scan, y se documentó honestamente.

### 1.2 Índice parcial ix_producto_stock_reposicion
- **Spec (Kiro):** `specs/indice_producto_stock_reposicion.md` — productos a reponer,
  columna `stock`, reporte paginado.
- **Propuesta de la IA:** **índice parcial** `ON producto (stock) WHERE stock < 50`.
- **Verificación:** antes Seq Scan 50 k + Sort (10.4 ms) → después `Index Scan` parcial +
  `Incremental Sort` presorted (0.34 ms, **×30.4**).
- **Decisión:** aceptado. El parcial se justificó con el criterio de teoría (indexar solo
  las 12,4 k filas relevantes) y se midió.

### 1.3 Índice ix_cliente_apellido_nombre
- **Spec (Kiro):** `specs/indice_cliente_apellido_nombre.md` — buscador de clientes por
  apellido con paginación.
- **Propuesta de la IA:** compuesto `(apellido text_pattern_ops, nombre text_pattern_ops)`.
- **Verificación:** antes Seq Scan 20 k (2.75 ms) → después Bitmap con `Index Cond` de
  prefijo + top-N sort (1.40 ms, **×2**). Se documentó el rol de la **opclass** (requisito
  para LIKE con B-tree en collation no-C), que es contenido de la teoría de "tipos de índice".

### 1.4 Descartado por sobreindexación (obligatorio de la bitácora) — D1
- **Spec:** propuesta de la IA sin spec (se evaluó a contraprueba):
  `CREATE INDEX idx_detalle_cantidad ON detalle_pedido (cantidad);` para Q3 (top por unidades).
- **Qué propuso la IA:** "indexar cantidad para acelerar el SUM".
- **Qué se verificó:** en transacción reversible se creó el índice y se midió Q3: **el plan
  sigue siendo `Seq Scan` sobre 512 k líneas + HashAggregate** (316 ms); el índice nunca
  aparece. Es una agregación de tabla completa.
- **Decisión:** **DESCARTADO** por sobreindexación (`specs/descartado_detalle_cantidad.md`).
  La IA proponía delegar; el plan desconfió la intuición "un índice siempre ayuda".

### 1.5 Descartado por redundancia — D2
- **Propuesta:** `idx_pedido_cliente_estado (cliente_id, estado)`.
- **Qué se decidió:** redundante con `idx_pedido_cliente` (~10 pedidos/cliente) + estado de
  cardinalidad 4; no cambia Q2 y suma mantenimiento. Descartado
  (`specs/descartado_pedido_cliente_estado.md`).

### 1.6 Costo de escritura (Parte A.5)
- Scripts `sql/prueba_escritura_antes.sql` / `despues.sql`: pedido +1.4 %, líneas dentro
  del ruido (los índices nuevos no tocan `detalle_pedido`). Números en `informe_mediciones.md` §A.5.

---

## 2. Vistas (Parte B)

- **Specs (Kiro):** 4 archivos en `specs/` (`vista_reporte_productos_vigentes.md`,
  `vista_reporte_pedidos_cliente.md`, `vista_reporte_detalle_pedido.md`,
  `vista_cliente_contacto_seguridad.md`), con columnas a exponer, filtros y qué ocultar.
- **Generación (OpenCode):** `sql/views.sql` (3 vistas de reportes + vista de seguridad).
- **Verificación de equivalencia (requisito mínimo de la bitácora, Parte B.3):**
  `sql/verificacion_views.sql` — filas idénticas y **`EXCEPT` 0/0 en ambas direcciones**
  para las 4 vistas (50.006 / 212.003 / 512.014 / 20.003 filas). Además se comprobó que la
  vista de seguridad **no expone la columna `telefono`** (0 en `information_schema.columns`).
- **Decisión:** aceptadas sin modificaciones. La vista de seguridad aplica el criterio de
  mínima exposición; se documentó la **adaptación** (el modelo local no tiene `contraseña`;
  el dato sensible es `telefono`) para la defensa oral.

---

## 3. Vista materializada (Parte C)

- **Spec (Kiro):** `specs/materializada_facturacion_categoria_mes_pago.md`.
- **Generación (OpenCode):** `sql/materializadas.sql` — `CREATE MATERIALIZED VIEW ... WITH
  DATA` + índice **ÚNICO** `(categoria, mes, forma_pago)` + índice por `mes`.
- **Verificación (requisito mínimo del TP, medición):** original 905.8 ms vs MV **0.022 ms
  (×41.000)**; `REFRESH CONCURRENTLY` probado y funcionando; equivalencia MV ↔ original
  `EXCEPT` 0/0 (`sql/verificacion_materializada.sql`).
- **Decisión:** aceptada. Frecuencia de refresco sugerida y efecto del dato "viejo" en
  `informe_mediciones.md` §Parte C.

---

## 4. Resumen de decisiones IA → humano

| Pieza | Propuso IA | Se aceptó | Se modificó | Se descartó | Evidencia |
|---|---|---|---|---|---|
| ix_pedido_fecha_estado | ✔ | ✔ | — | — | planes5/A1 ×1.6 |
| ix_producto_stock_reposicion | ✔ (parcial) | ✔ | — | — | planes5/A2 ×30.4 |
| ix_cliente_apellido_nombre | ✔ (opclass) | ✔ | — | — | planes5/A3 ×2 |
| idx_detalle_cantidad (D1) | ✔ | — | — | **✔ sobreindexación** | plan sigue Seq Scan |
| idx_pedido_cliente_estado (D2) | ✔ | — | — | **✔ redundante** | análisis + specs |
| 4 vistas | ✔ | ✔ | — | — | EXCEPT 0/0 |
| MV + índice único | ✔ | ✔ | — | — | ×41.000 + CONCURRENTLY |

Ningún script se ejecutó sin leerlo línea por línea y sin haberlo cargado sobre la copia
`food_store_tp5` (protocolo de seguridad de la cátedra).