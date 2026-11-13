# design.md — Unidad 4 (TP6)

**Proyecto:** Food Store · **Unidad:** 4 · **Base de trabajo:** `food_store_tp6`
**Scripts:** `TP6/tp_fnbc_control_lote.sql`, `TP6/tp_desnormalizacion_top_categorias.sql`

## 1. Parte 1 — FNBC sobre `control_lote_almacen`

### 1.1 Relación y dependencias funcionales

`R = control_lote_almacen (LoteID, DepositoID, ResponsableControlID)`

| DF | Lectura de negocio | Origen |
|---|---|---|
| `{LoteID, DepositoID} → {ResponsableControlID}` (FD1) | Para un lote y un depósito interviniente, el responsable de control queda unívocamente determinado | Regla de logística |
| `{ResponsableControlID} → {DepositoID}` (FD2) | Cada responsable pertenece a un único depósito: no controla lotes coordinados desde depósitos distintos | Dato maestro de personal |

`F+` mínima: las dos DF anteriores. `usuario` se crea **sin** `deposito_id`
a propósito: si el maestro ya guardara el depósito del responsable, FD2 no
estaría en `control_lote_almacen` y no habría nada que descomponer.

### 1.2 Clausuras y claves candidatas

| X | X+ |
|---|---|
| `{LoteID}` | `{LoteID}` |
| `{DepositoID}` | `{DepositoID}` |
| `{ResponsableControlID}` | `{ResponsableControlID, DepositoID}` |
| `{LoteID, DepositoID}` | `R` |
| `{LoteID, ResponsableControlID}` | `R` |
| `{DepositoID, ResponsableControlID}` | `{DepositoID, ResponsableControlID}` |

Claves candidatas: **K1 = {LoteID, DepositoID}** (elegida como PK) y
**K2 = {LoteID, ResponsableControlID}**. Los tres atributos son primos; no hay
atributos no primos.

### 1.3 Por qué 3FN sí y FNBC no

- **3FN:** todo determinante no trivial es superclave **o** atributo primo.
  `ResponsableControlID` es primo (está en K2), así que la definición de 3FN se
  satisface aun cuando FD2 no tenga superclave como determinante.
- **FNBC:** exige superclave en **todo** determinante. `{ResponsableControlID}+`
  no contiene `LoteID`, luego no es superclave → **viola FNBC**.

Éste es el caso canónico donde las dos definiciones se separan: sin atributos
no primos, 3FN no detecta nada.

### 1.4 Anomalías demostradas

| Anomalía | Operación | Qué se pierde |
|---|---|---|
| Inserción | Registrar un responsable nuevo sin asignarle un lote | No hay fila donde guardar `ResponsableControlID → DepositoID` |
| Actualización | Mover un responsable de depósito | Hay que actualizar N filas; si una queda vieja, el mismo responsable aparece en dos depósitos |
| Borrado | Borrar la última asignación de un lote | Se pierde el depósito del responsable, que era un dato maestro |

Cada una se ejecuta dentro de un `SAVEPOINT` y se revierte con `ROLLBACK TO`,
para no dejar el esquema en un estado inconsistente.

### 1.5 Descomposición y verificación de pérdida

**Variante implementada (script entregado):**

- `r1 = responsable_deposito (responsable_control_id PK, deposito_id)`
- `r2 = control_lote (lote_id, deposito_id)`

Ambas están en FNBC (`r1`: el determinante de FD2 es su PK; `r2`: solo queda FD1
y su determinante es la PK). Pero **la reunión es con pérdida**:
`r1 ∩ r2 = {DepositoID}`, y `{DepositoID}+ = {DepositoID}` no contiene
`ResponsableControlID` ni `LoteID`, así que no es superclave de `r1` ni de `r2`.

El `EXCEPT` bidireccional del script da 0/0 únicamente porque la instancia de
ejemplo tiene **un responsable por depósito** (801→30, 802→31): la reunión
coincide con el original por casualidad de los datos. Con un segundo responsable
en el depósito 30, `r1 ⋈ r2` produce filas espurias. Es el hallazgo **F-U4-4**
del code review.

**Variante correcta (propuesta):** algoritmo estándar con `X = {ResponsableControlID}`,
`X+ = {ResponsableControlID, DepositoID}`:

- `R1 = X+ = responsable_deposito (responsable_control_id, deposito_id)`
- `R2 = (R − X+) ∪ X = control_lote (lote_id, responsable_control_id)`
- `R1 ∩ R2 = {ResponsableControlID}` y `{ResponsableControlID}+ = R1`, por lo que
  la reunión **sí** es sin pérdida.

Costo de la corrección: la DF `{LoteID, DepositoID} → ResponsableControlID` deja
de ser una restricción declarativa (BCNF no garantiza preservación de
dependencias). Se compensa con un `UNIQUE`/disparador sobre la vista o se acepta
como dependencia verificada por aplicación. Es una decisión pendiente del equipo.

`responsable_deposito` declara `UNIQUE (deposito_id, responsable_control_id)` y
PK sobre `responsable_control_id`: la regla «un responsable, un depósito» deja
de depender de la disciplina de la aplicación.

### 1.6 Vista de compatibilidad

La vista entregada reproduce el esquema original:

```sql
SELECT cl.lote_id, cl.deposito_id, rd.responsable_control_id
  FROM control_lote cl
  JOIN responsable_deposito rd ON rd.deposito_id = cl.deposito_id;
```

Con la variante implementada, esta vista solo es fiel mientras cada depósito
tenga un responsable. Por eso **no sirve como oráculo** de equivalencia
(F-U4-4): el `EXCEPT` 0/0 mide la instancia, no la descomposición.

Con la variante correcta, la vista sí reconstruye sin pérdida:

```sql
SELECT cl.lote_id, rd.deposito_id, cl.responsable_control_id
  FROM control_lote cl
  JOIN responsable_deposito rd USING (responsable_control_id);
```

## 2. Parte 2 — Desnormalización controlada

### 2.1 Punto de partida medido

Consulta normalizada de 4 tablas
(`detalle_pedido ⋈ pedido ⋈ producto ⋈ categoria`, filtro por día y
`estado <> 'CANCELADO'`, `GROUP BY categoria`, `ORDER BY total DESC LIMIT 5`):

| Métrica | Valor |
|---|---|
| Plan dominante | `Parallel Seq Scan` sobre `detalle_pedido` |
| Filas leídas | ~549.529 |
| Buffers | 5.004 |
| Tiempo | **138,0 ms** (233,2 ms en frío) |

El motor lee medio millón de filas para responder sobre ~31.372 líneas del día:
el costo está en el volumen explorado, no en el `GROUP BY`.

### 2.2 Estructura

`fact_venta_categoria_dia` — grano **día × categoría**:

| Columna | Tipo | Rol |
|---|---|---|
| `fecha` | `DATE` | Parte de la PK natural |
| `categoria_id` | `BIGINT` | Parte de la PK, FK `ON DELETE RESTRICT` |
| `categoria_nombre` | `VARCHAR(80)` | Copia controlada del nombre |
| `total_vendido` | `NUMERIC(14,2)` | Agregado (14,2 porque el agregado puede superar el 12,2 de la línea) |
| `lineas` | `INTEGER` | Cantidad de líneas |
| `actualizado_en` | `TIMESTAMPTZ` | Trazabilidad del refresco |

Restricciones: `PK (fecha, categoria_id)`, `CHECK (total_vendido >= 0)`,
`CHECK (lineas >= 0)`, `INDEX ix_fact_venta_total (total_vendido DESC)`.

Sin clave sustituta: el grano **es** la identidad de la fila y la PK natural es
lo que habilita los upserts incrementales.

### 2.3 Mecanismo de sincronización

Regla de oro: toda escritura que pueda mover el agregado tiene un disparador
que lo mueve en la **misma transacción**.

| Disparador | Tabla | Camino | Acción |
|---|---|---|---|
| `trg_detalle_fact_ins` | `detalle_pedido` | Caliente | Delta O(1) por línea insertada |
| `trg_detalle_fact_del` | `detalle_pedido` | Caliente | Delta O(1) negativo |
| `trg_detalle_fact_upd` | `detalle_pedido` | Caliente | Revierte el delta viejo y aplica el nuevo |
| `trg_pedido_fact_upd` | `pedido` | Frío | Recalcula el día afectado (cambio de fecha o de estado) |
| `trg_producto_fact_cat` | `producto` | Frío | Recalcula los días afectados (recategorización) |
| `trg_categoria_fact_nombre` | `categoria` | Frío | Propaga el nombre a las filas del cubo |

- **Camino caliente:** operación del mostrador; no puede pagar el recálculo del
  día. Costo O(1) por línea.
- **Camino frío:** cambios raros y de alcance ancho; se **recalcula** el día con
  la misma agregación del auditor. Es correcto por construcción, no por
  propagación manual.
- Si el cubo queda sin líneas, la fila se borra: el cubo debe tener exactamente
  las filas que devolvería el `GROUP BY` normalizado (una categoría totalmente
  cancelada no aparece con total 0).
- La regla de negocio es la misma en los dos caminos: cuenta si
  `pedido.estado <> 'CANCELADO'`.

### 2.4 Poblado inicial

El backfill usa el **mismo** `SELECT` que la consulta auditora y se ejecuta con
`trg_detalle_stock` deshabilitado (el backfill solo lee; se apaga por si el
lector reescribiera algo) y se vuelve a habilitar de inmediato. Después:
`ANALYZE fact_venta_categoria_dia` y control de carga con
`count(*) / min(fecha) / max(fecha)`.

### 2.5 Resultado

| Antes (4 tablas) | Después (cubo) |
|---|---|
| `Parallel Seq Scan` — ~549.529 filas, 5.004 buffers | `Bitmap Index Scan` + `Heap Scan` — 3 filas, 6 buffers |
| **138,0 ms** (233,2 ms en frío) | **0,118 ms** |

Equivalencia: `EXCEPT` bidireccional entre la consulta normalizada y la lectura
del cubo → 0 filas en ambos sentidos.

## 3. Reversibilidad

### 3.1 Parte 1

```sql
BEGIN;
DROP VIEW  IF EXISTS control_lote_almacen_compat;
DROP TABLE IF EXISTS control_lote;
DROP TABLE IF EXISTS responsable_deposito;
COMMIT;
```

`control_lote_almacen` (la tabla original) **no se borra**: la descomposición se
agrega al lado y se compara contra ella. Revertir es borrar las dos tablas
nuevas y la vista; el estado previo queda intacto.

### 3.2 Parte 2

```sql
BEGIN;
DROP TABLE IF EXISTS fact_venta_categoria_dia CASCADE;
COMMIT;
```

Los disparadores caen con la tabla. La fuente de verdad (`pedido`,
`detalle_pedido`, `producto`, `categoria`) nunca se altera, por lo que el
sistema sigue operando sin el cubo y el reporte vuelve a la consulta de 4
tablas. **Reaplicar es volver a ejecutar el script**: `DROP` + backfill
reconstruye el estado exacto (documentado en el script como operación de
reversibilidad).

### 3.3 Verificación de la reversión

1. `\d fact_venta_categoria_dia` → no existe.
2. `SELECT count(*) FROM detalle_pedido;` → mismo valor que antes del `DROP`.
3. `SELECT count(*), sum(cantidad) FROM detalle_pedido;` → sin cambios.
4. Reejecutar el script en la copia y comparar el `EXCEPT` de equivalencia →
   0 filas.

## 4. Decisiones descartadas

| Alternativa | Por qué se descarta |
|---|---|
| Guardar `pedido.total` | Dependencia transitiva; viola 3FN y el esquema ya documenta que es derivable |
| Vista materializada | `REFRESH` no sostiene el camino incremental en tiempo real |
| Recálculo nocturno | El panel necesita el dato del día en el momento |
| Índice sobre `detalle_pedido(cantidad)` | No cambia el plan de agregación (sigue `Seq Scan`); verificado |
| `VACUUM FULL` periódico | Bloquea y reescribe la tabla; política adoptada en U6 |

## 5. Trazabilidad

| Requisito | Sección |
|---|---|
| R-U4-01…03 | §1.1, §1.2, §1.3 |
| R-U4-04 | §1.4 |
| R-U4-05…07 | §1.5, §1.6 |
| R-U4-08 | §2.1 |
| R-U4-09…12 | §2.2, §2.3, §2.4 |
| R-U4-13 | §2.5 |
| R-U4-14 | §3 |
| R-U4-15…19 | §2.1, §2.4, §4 |
