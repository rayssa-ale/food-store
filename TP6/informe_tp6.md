# Informe breve — Unidad 4: FNBC y Desnormalización Controlada en Food Store

## 1. Parte 1 — ControlLoteAlmacen

### (a) Dependencias funcionales (notación formal)

Sobre el esquema R = {LoteID, DepositoID, ResponsableControlID} se desprenden, a partir del enunciado:

- FD1: {LoteID, DepositoID} → {ResponsableControlID}  
  "Para un lote y un depósito interviniente dados, el responsable de control queda unívocamente determinado."
- FD2: {ResponsableControlID} → {DepositoID}  
  "Cada responsable de control pertenece, como dato maestro de la dotación de personal, a un único depósito: no controla lotes coordinados desde depósitos distintos."

F+ contiene únicamente estas dos dependencias.

### (b) Clausuras y claves candidatas

Clausuras relevantes:

- {ResponsableControlID}+ = {ResponsableControlID, DepositoID} (por FD2)
- {LoteID, DepositoID}+ = {LoteID, DepositoID, ResponsableControlID} (por FD1)
- {LoteID, ResponsableControlID}+ = {LoteID, ResponsableControlID, DepositoID} (aplica FD2 y luego FD1)

Claves candidatas (K):

- K1 = {LoteID, DepositoID} — superclave mínima
- K2 = {LoteID, ResponsableControlID} — superclave mínima

Atributos primos: LoteID, DepositoID, ResponsableControlID (todos pertenecen a alguna clave candidata). No existen atributos no primos.

### (c) FNBC (definición formal)

Para toda DF X → Y no trivial en r, X debe ser superclave.

- FD1: determinante {LoteID, DepositoID} = K1 → es superclave → no viola.
- FD2: determinante {ResponsableControlID} → {ResponsableControlID}+ = {ResponsableControlID, DepositoID} ⊂ R → NO es superclave → **VIOLA FNBC**.

Por ello, `control_lote_almacen` no cumple FNBC. Sí cumple 3FN en este caso (no hay atributos no primos), lo cual es el caso canónico donde 3FN y FNBC se separan.

### (d) Anomalías (instancia de ejemplo: (501,30,801), (502,30,801), (503,31,802))

1. **Inserción**: no se puede registrar que el responsable 803 pertenece al depósito 31 sin asignarlo a algún lote. Para darlo de alta se debe inventar un lote (ej. 504), lo cual crea una fila artificial sobre la relación de control.
2. **Borrado**: si se borra la única asignación del responsable 802 (lote 503), desaparece la única información que indica que 802 pertenece al depósito 31. Se pierde el dato maestro de dotación de personal al borrar una asignación.
3. **Actualización**: si el responsable 801 cambia de depósito (30 → 31), el cambio es múltiple: modificar (501,30,801) y (502,30,801) implica borrar e insertar filas (la PK incluye `deposito_id`) y, si se hace parcial (solo un lote), queda registrado en dos depósitos distintos, violando la regla "un único depósito".

Las tres anomalías están demostradas con SQL ejecutable dentro de SAVEPOINTs que se revierten (no alteran la base).

### (e) Descomposición sin pérdida

Aplicando el algoritmo para X → Y con X = {ResponsableControlID}, Y = {DepositoID}:

- r1 = X ∪ Y = {ResponsableControlID, DepositoID}  
  PK de r1 = {ResponsableControlID} → FNBC.
- r2 = r \ (X \ Y) = {LoteID, DepositoID}  
  PK de r2 = {LoteID, DepositoID} → FNBC.

Tablas resultantes (ver `tp_fnbc_control_lote.sql`):

- `responsable_deposito(responsable_control_id PK FK→usuario, deposito_id FK→deposito, created_at)`
- `control_lote(lote_id FK→lote, deposito_id FK→deposito, created_at, PK(lote_id, deposito_id))`

Vista de compatibilidad (reunión natural sobre `deposito_id`):

```sql
CREATE VIEW control_lote_almacen_compat AS
SELECT cl.lote_id, cl.deposito_id, rd.responsable_control_id
  FROM control_lote cl
  JOIN responsable_deposito rd ON rd.deposito_id = cl.deposito_id;
```

### (f) Unión sin pérdida — justificación (superclave sobre atributo común)

El atributo común de la reunión es `DepositoID`. Teorema: la reunión natural de r1 y r2 sobre r1∩r2 es sin pérdida si y solo si r1∩r2 es una superclave de al menos una de las dos relaciones.

- r2 = `control_lote` tiene PK = {lote_id, deposito_id}, por lo que `DepositoID` forma parte de su clave primaria → **es superclave de r2**.
- Por consiguiente, `responsable_deposito ⋈ control_lote` es **sin pérdida**.

Verificación empírica (ejecutada): `EXCEPT ALL` en ambas direcciones devuelve **0 filas**; cardinalidad idéntica (3 = 3) y firma (suma de claves) idéntica entre original y vista.

## 2. Parte 2 — Consulta con desnormalización controlada

### (a) EXPLAIN ANALYZE (línea base)

Consulta adaptada al esquema real (TIMESTAMPTZ vs DATE; baja lógica por ENUM):

```sql
SELECT c.nombre AS categoria,
       SUM(d.cantidad * d.precio_unitario) AS total_vendido
FROM detalle_pedido d
JOIN pedido pe ON pe.id = d.pedido_id
JOIN producto p ON p.id = d.producto_id
JOIN categoria c ON c.id = p.categoria_id
WHERE pe.fecha >= CURRENT_DATE
  AND pe.fecha < CURRENT_DATE + INTERVAL '1 day'
  AND pe.estado <> 'CANCELADO'
GROUP BY c.nombre
ORDER BY total_vendido DESC
LIMIT 5;
```

**Nota sobre el predicado de fecha**: `ped.fecha` es TIMESTAMPTZ y `CURRENT_DATE` es DATE; la igualdad literal `fecha = CURRENT_DATE` resuelve contra la medianoche local exacta y, sobre el día más cargado de la base (2026-09-22, 12.269 pedidos), devuelve **0 filas** en lugar de 12.269. Por eso se usa el predicado de rango `fecha >= CURRENT_DATE AND fecha < CURRENT_DATE + 1 day`, equivalente a `fecha::date = CURRENT_DATE` y sargable (usa `ix_pedido_fecha_estado`).

Medición sobre 15.000 pedidos / 37.500 líneas del día (base food_store_tp6):

- **Frío**: Execution Time = 233,234 ms
- **Caliente (mediana de 5 corridas)**: ≈ 138 ms (130,268 / 137,602 / 138,280 / 140,289 / 154,845)

**Nodo dominante**: `Parallel Seq Scan on public.detalle_pedido` (183.176 filas por worker × 3 = ~549.529 filas leídas) para responder sobre ~31.372 líneas. Lee ~17,5× más datos de los necesarios. Buffers: shared hit=1724 read=3280.

Plan completo: `TP6/planes/D1_top5_categorias_antes.txt`.

### (b) Justificación del patrón elegido

Se eligió **estructura agregada precalculada mantenida con disparadores** (`fact_venta_categoria_dia` + triggers AFTER sobre `detalle_pedido`, `pedido`, `producto`, `categoria`), por sobre una vista materializada.

- **¿Qué evidencia medida motiva la decisión?** La consulta de línea base está dominada por `Parallel Seq Scan` sobre `detalle_pedido`: lee ~549.529 filas (85 MB de tabla) para filtrar un día y agrupar por categoría (~31.372 líneas útiles). El costo NO está en el JOIN final sino en recorrer la tabla de líneas completa. Un cubo con grano (fecha, categoría) reduce la lectura del día corriente a **1 bloque y 3 filas**, atacando exactamente el nodo dominante del plan medido.

- **¿Qué mecanismo garantiza que el dato redundante no se desincronice?** Dos caminos, ambos dentro de la misma transacción que escribe la fuente (por eso o escriben ambos o no escribe ninguno):
  - *Camino caliente* (INSERT/DELETE de `detalle_pedido`): ajuste incremental del cubo con delta atómico (`ajustar_fact_venta`), sumando sólo si el pedido **no está CANCELADO** — el mismo criterio del `WHERE` original.
  - *Camino frío* (cambios de alcance ancho: mover la fecha de un pedido, cruzar la frontera CANCELADO, recategorizar un producto): `recalcular_fact_venta_dia(fecha)` **reconstruye el día completo** con la misma agregación que usa el auditor; es correcto por construcción y no depende de propagar impactos a mano.
  - El nombre de categoría (dato copiado) se propaga con trigger `AFTER UPDATE OF nombre ON categoria`, y el backfill usa la misma agregación.
  - La **auditoría (5.2e)** recalcula desde la fuente de verdad y compara en **ambas direcciones** los tres datos redundantes (total, líneas y nombre). Resultado vacío sobre la base migrada; y se demuestra que tiene dientes rompiendo el dato a propósito dentro de un ROLLBACK.

- **¿Es reversible sin pérdida de información?** Sí. `fact_venta_categoria_dia` es **100 % derivable** de `pedido`/`detalle_pedido`/`producto`/`categoria`. Se elimina con `DROP TABLE` y se reconstruye ejecutando el backfill incluido. Ninguna fila de la fuente de verdad se modifica.

**Por qué no una vista materializada**: el panel requiere tiempo real con actualización frecuente. Una MV exige `REFRESH` (completo o `CONCURRENTLY`), un proceso por lote y no reactivo a cada línea; entre refrescos el dato queda viejo y hay ventana de desincronización. Los disparadores mantienen el cubo al día por fila y con garantías ACID. TP5 ya midió MV para otro grano (mes/forma de pago) y con otro propósito.

### (c) Implementación

Ver `tp_desnormalizacion_top_categorias.sql`:

- Tabla: `fact_venta_categoria_dia(fecha DATE, categoria_id BIGINT, categoria_nombre VARCHAR(80), total_vendido NUMERIC(14,2), lineas INTEGER, actualizado_en TIMESTAMPTZ, PK(fecha,categoria_id), FK→categoria, CHECK no negativos)` — grano = clave natural, lo que habilita upserts incrementales.
- Funciones: `ajustar_fact_venta`, `recalcular_fact_venta_dia`, y las funciones de trigger (ins/del/upd de detalle; upd de pedido; upd de producto; upd de categoría).
- Backfill inicial con la misma agregación del auditor.
- Pruebas de sincronización (INSERT y cancelación) dentro de transacciones revertidas.

### (d) Comparación antes/después (EXPLAIN ANALYZE)

Consulta sobre la estructura desnormalizada:

```sql
SELECT fv.categoria_nombre AS categoria, fv.total_vendido
  FROM fact_venta_categoria_dia fv
 WHERE fv.fecha = CURRENT_DATE
 ORDER BY fv.total_vendido DESC
 LIMIT 5;
```

**Después (mediana de 5 corridas)**: Execution Time ≈ **0,118 ms** (0,104 / 0,109 / 0,118 / 0,175 / 0,179 ms).
Plan: `Bitmap Index Scan` sobre `pk_fact_venta_categoria_dia` → `Bitmap Heap Scan` (Heap Blocks: 1) → `Sort` por `total_vendido DESC`. Buffers: shared hit=6.

| Métrica | Antes (normalizado, 4 tablas) | Después (estructura desnormalizada) |
|---|---|---|
| Nodo dominante | **Parallel Seq Scan** sobre detalle_pedido | **Bitmap Index/Heap Scan** sobre fact_venta_categoria_dia |
| Filas leídas | ~549.529 (detalle_pedido) para ~31.372 líneas útiles | ~7 (índice) → 3 filas devueltas |
| Buffers | shared hit=1724 read=3280 | shared hit=6 |
| Tiempo (frío) | **233,234 ms** | **0,155 ms** |
| Tiempo (caliente, mediana) | **138,0 ms** | **0,118 ms** |

**Ganancia ≈ ×1.170** (138 ms → 0,118 ms). El salto es cualitativo: de leer medio millón de filas a leer 3.

Planes completos: `TP6/planes/D1_top5_categorias_antes.txt` y `TP6/planes/D1_top5_categorias_despues.txt`.

### (e) Script de auditoría (resultado vacío sobre la base migrada)

La auditoría (5.2e) compara `(fecha, categoria_id, categoria_nombre, total_vendido, lineas)` entre la verdad (4 tablas, `estado <> 'CANCELADO'`) y lo almacenado, en **ambas direcciones** (`cubo_faltante` / `distinto`). Sobre la base migrada devuelve **0 filas**. Se incluye además una prueba que rompe un monto a propósito (dentro de ROLLBACK) para confirmar que la auditoría detecta la desincronización.

## 3. Artefactos entregados

1. `tp_fnbc_control_lote.sql` — Parte 1: DDLs, instancia de ejemplo, demostración de las 3 anomalías (con SAVEPOINTs), descomposición, vista de compatibilidad, migración verificada con EXCEPT ALL y firma de equivalencia, justificación teórica de la unión sin pérdida.
2. `tp_desnormalizacion_top_categorias.sql` — Parte 2: estructura desnormalizada, mecanismo de sincronización (disparadores), backfill, equivalencia EXCEPT ALL entre antes/después, auditoría con doble dirección, prueba de detección (deliberate break) y pruebas de sincronización (todas revertidas con ROLLBACK), sección de reversibilidad.
3. Este informe (PDF/Word) + `TP6/informe_resumen.txt` con los extractos de los planes; planes textuales completos en `TP6/planes/`.

**Ejecución verificada sobre `food_store_tp6`** (PostgreSQL 18 local). Toda afirmación técnica está acompañada del SQL o de la salida de EXPLAIN ANALYZE que la demuestra.