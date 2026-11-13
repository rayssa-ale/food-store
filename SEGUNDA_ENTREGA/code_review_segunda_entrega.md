# Code review — scripts de la segunda entrega (U4–U8)

**Proyecto:** Food Store · **Equipo G** · **Fecha:** noviembre de 2026
**Alcance:** todos los scripts entregados en U4–U8.
**Método:** revisión estática línea por línea + contraste contra `schema.sql`
(única fuente de verdad del modelo publicado) + verificación de las salidas ya
ejecutadas por el equipo. Los hallazgos de ejecución se marcan como tales; el
resto es revisión de código.

## Escala de severidad

| Nivel | Criterio |
|---|---|
| **Alta** | Rompe la reproducibilidad, la integridad o el mínimo privilegio; o el script no corre sobre el esquema publicado |
| **Media** | Funciona hoy, pero el patrón es frágil, inseguro o no idempotente |
| **Baja** | Deuda de estilo, documentación o eficiencia menor |

Cada hallazgo tiene una decisión: **corregido** (se cambió el artefacto),
**mitigado** (se agregó una salvaguarda) o **documentado** (se acepta con
justificación y queda como deuda).

## Resumen

| ID | Unidad | Hallazgo | Severidad | Decisión |
|---|---|---|---|---|
| F-U4-1 | U4 | `fecha = CURRENT_DATE` devuelve 0 filas sobre `TIMESTAMPTZ` | Alta | Corregido |
| F-U4-2 | U4 | Backfill con `trg_detalle_stock` deshabilitado | Media | Mitigado |
| F-U4-3 | U4 | Cubo sin política de retención | Baja | Documentado |
| F-U4-4 | U4 | La descomposición `(Resp, Dep) + (Lote, Dep)` era **con pérdida** en general y el `EXCEPT` 0/0 solo pasaba por la instancia de ejemplo | Alta | Corregido |
| F-U5-1 | U5 | `GRANT ALL`, `SELECT` sobre todo y `DELETE` general | Alta | Rechazado |
| F-U5-2 | U5 | Distribución de roles inventada (10.000/10.000) | Alta | Corregido |
| F-U5-3 | U5 | Log de auditoría en OneDrive con ACL permisiva | Media | Documentado |
| F-U5-4 | U5 | `id` y mes como cuasi-identificadores en `usuario_anon` | Media | Documentado |
| F-U6-1 | U6 | `--no-privileges` deja `app_web` sin acceso tras el restore | Alta | Corregido |
| F-U6-2 | U6 | `VACUUM FULL` propuesto como mantenimiento periódico | Alta | Rechazado |
| F-U6-3 | U6 | RPO de 6 h atado a la frecuencia del respaldo | Media | Documentado |
| F-U7-1 | U7 | SQL equivalente con catálogo inexistente (`usuario`, `total`, `TERMINADO`) | Alta | Documentado + corregido |
| F-U7-2 | U7 | `insertMany` sin transacción y `drop()` previo | Media | Documentado |
| F-U7-3 | U7 | PII real en el código de la migración | Media | Documentado |
| F-U7-4 | U7 | Dinero en `double` | Baja | Documentado |
| F-U7-5 | U7 | Proyección de 4.a no coincide con su comentario | Baja | Corregido |
| F-U8-1 | U8 | `precio REAL` para dinero | Alta | Corregido |
| F-U8-2 | U8 | Borrado físico de `producto_cache` | Alta | Corregido |
| F-U8-3 | U8 | Reevaluación de solicitudes ya resueltas | Media | Corregido |
| F-U8-4 | U8 | Booleanos `0/1` supuestos al importar el CSV | Media | Corregido |
| F-U8-5 | U8 | Índice `detalle_pedido(cantidad)` propuesto | Baja | Rechazado |

## 1. Unidad 4

### F-U4-1 · `fecha = CURRENT_DATE` sobre `TIMESTAMPTZ` — Alta · Corregido

**Qué pasaba.** La consulta del top 5 filtraba `pe.fecha = CURRENT_DATE`. En
una columna `TIMESTAMPTZ`, esa igualdad compara contra la medianoche con zona
horaria: de los 12.269 pedidos de un día real devolvía **0 filas** y el
`EXPLAIN ANALYZE` medía un conjunto vacío.

**Corrección.** Predicado de rango semiabierto:

```sql
WHERE pe.fecha >= CURRENT_DATE
  AND pe.fecha <  CURRENT_DATE + INTERVAL '1 day'
```

**Evidencia.** `TP6/tp_desnormalizacion_top_categorias.sql` (bloque del
auditor) y `TP6/TP6_Food_Store.pdf`.

### F-U4-2 · Backfill con un disparador deshabilitado — Media · Mitigado

`ALTER TABLE detalle_pedido DISABLE TRIGGER trg_detalle_stock` se ejecuta dentro
de la transacción y se vuelve a habilitar inmediatamente después del
`INSERT ... SELECT`. En PostgreSQL el `ALTER TABLE` es transaccional: si el
backfill falla, el `ROLLBACK` deja el disparador habilitado. El riesgo real es
un `COMMIT` intermedio mal ubicado.

**Mitigación.** `BEGIN` … `COMMIT` único alrededor de todo el bloque y
verificación posterior con `SELECT tgname, tgenabled FROM pg_trigger`. Queda
como advertencia en el script.

### F-U4-3 · Cubo sin retención — Baja · Documentado

`fact_venta_categoria_dia` crece una fila por día y categoría. Al volumen actual
es despreciable; no hay política de purga. Se documenta como deuda de
mantenimiento (U6).

### F-U4-4 · La descomposición aplicada no era sin pérdida en general — Alta · Corregido

**Qué se encontró.** La primera versión del script descomponía

- `responsable_deposito (responsable_control_id PK, deposito_id)`
- `control_lote (lote_id, deposito_id)` — sin `responsable_control_id`

y afirmaba que la reunión era sin pérdida porque «`DepositoID` es clave de
`control_lote`». **No lo es:** la clave de `control_lote` era el par
`(lote_id, deposito_id)` y la de `responsable_deposito` es
`responsable_control_id` (un depósito tiene varios responsables). Con el
criterio de superclave, `{DepositoID}+ = {DepositoID}`, que no contiene ni
`ResponsableControlID` ni `LoteID`: la descomposición **era con pérdida**.

**Contraejemplo.** Con dos lotes y dos responsables en el depósito 30 —
original `(501,30,801)` y `(502,30,803)`, 2 filas —, la reunión por
`deposito_id` devuelve **4**: aparecen `(501,30,803)` y `(502,30,801)`, pares
que nunca existieron. El responsable que no controlaba el lote aparece como si
lo controlara.

**Por qué la verificación no lo detectaba.** La instancia de ejemplo tiene **un
solo responsable por depósito** (801→30, 802→31), así que la reunión coincidía
con el original y el `EXCEPT` bidireccional daba 0/0. La prueba pasaba por
casualidad de la instancia, no por corrección del esquema.

**Corrección aplicada** (descomposición estándar `r1 = X ∪ Y`, `r2 = R \ Y`):

- `responsable_deposito (responsable_control_id PK, deposito_id)` — sin cambios.
- `control_lote (lote_id, responsable_control_id)` — clave
  `(lote_id, responsable_control_id)`; se reúne por el responsable.
- Intersección `{responsable_control_id}`, que sí es clave de
  `responsable_deposito` (`Resp+ = {Resp, Dep}`): reunión **sin pérdida**.
- Vista: `SELECT cl.lote_id, rd.deposito_id, cl.responsable_control_id
  FROM control_lote cl JOIN responsable_deposito rd USING (responsable_control_id)`.
- El script ahora incluye el **contraejemplo ejecutable** de la variante
  descartada (tablas temporales: 4 filas contra las 2 del original) y la
  consulta inyectiva por `(lote_id, deposito_id)` como detector de violaciones
  de FD1.
- Costo declarado: la FNBC **no preserva** FD1 (`{Lote, Dep} → Resp`) como
  restricción de esquema; se documenta en el script y en el informe U4.

**Verificación de la corrección.** La lógica (chequeo previo de FD2, migración,
vista, `EXCEPT` 0/0, cardinalidad, firma, inyectividad y contraejemplo) fue
validada con una simulación paso a paso. Falta la **reejecución en el motor**
(no hubo contraseña de PostgreSQL disponible en la sesión de cierre):

```powershell
& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -U postgres -h localhost `
    -d food_store_tp6 -v ON_ERROR_STOP=1 -f TP6/tp_fnbc_control_lote.sql
```

El plan de reversión y el cubo de la Parte 2 no se ven afectados.

## 2. Unidad 5

### F-U5-1 · Permisos excesivos propuestos por la IA — Alta · Rechazado

La propuesta era `GRANT ALL PRIVILEGES`, `SELECT` sobre todas las tablas
—incluida `usuario`— «por simplicidad», `DELETE` en `rol_app_escritura` para
«completar el CRUD» y revisar tablas del sistema.

**Decisión.** Rechazado. Se mantuvo `SELECT` por columna sobre `usuario`, se
descartó `DELETE` general y `GRANT ALL`, y `pg_default_acl` quedó en 0 filas
(*default deny* con otorgamiento explícito). Evidencia:
`docs/verificacion_permisos.txt`.

### F-U5-2 · Distribución de roles inventada — Alta · Corregido

El borrador del informe afirmaba 10.000 `ADMIN` y 10.000 `USUARIO` sin haber
ejecutado la consulta. La salida real dio **20.000 `USUARIO` y 0 `ADMIN`** en un
único mes (2026-09).

**Corrección.** Se reemplazaron los valores por las capturas reales, se aclaró
la diferencia entre el dominio del ENUM (admite `ADMIN`) y la distribución
observada, y se agregó el control por `rol, (id % 10)` para que la equivalencia
no dependa de un agrupamiento mensual degenerado.

### F-U5-3 · Log de auditoría en OneDrive — Media · Documentado

El log vive en una carpeta sincronizada con la nube y con ACL de Windows
permisivas. Un log de auditoría es un activo sensible: quien lo lee conoce
actividad, rutas y errores.

**Decisión.** Se documenta como deuda de hardening (mover el log fuera de la
carpeta sincronizada y restringir la ACL). No se corrigió porque el entorno de
la práctica es una máquina personal.

### F-U5-4 · Cuasi-identificadores en `usuario_anon` — Media · Documentado

`id` y el mes de alta permiten, con información externa, reidentificar filas.
El script no promete k-anonimidad: es un **reemplazo determinista con utilidad
analítica preservada** y equivalencia **solo agregada**. Se declara
explícitamente en `docs/verificacion_equivalencia.md`.

## 3. Unidad 6

### F-U6-1 · `--no-privileges` deja los roles sin acceso — Alta · Corregido

`pg_restore --no-owner --no-privileges` restaura los datos, pero en la base
restaurada `has_table_privilege('app_web', 'pedido', 'SELECT')` devuelve `f`.
La restauración se consideraba exitosa mirando solo los conteos.

**Corrección.** El runbook de `TP6/restore_test.ps1` reaplica roles y `GRANT`s
después del restore y verifica con `has_table_privilege`. La validación de
integridad (`TP6/sql/validation_drill.sql`) corre después de esa reaplicación.

### F-U6-2 · `VACUUM FULL` periódico — Alta · Rechazado

La IA propuso `VACUUM FULL` como mantenimiento. Bloquea la tabla con un lock
exclusivo y reescribe el archivo completo: en un sistema en uso es una ventana
de indisponibilidad.

**Decisión.** Se mantiene `VACUUM (VERBOSE, ANALYZE)` y la política anti-`VACUUM
FULL` documentada en `TP6/SPEC_U6.md`.

### F-U6-3 · RPO atado a la frecuencia del respaldo — Media · Documentado

El RPO medido (6 h 00 m 26 s) es consecuencia de un respaldo diario. Si el
negocio exige menos pérdida, hay que acortar la frecuencia o pasar a WAL
archiving / PITR. Se documenta como decisión de negocio, no como límite técnico.
La programación diaria/semanal definida en `TP6/SPEC_U6.md` se materializa en
`TP6/schedule_u6.ps1` (tareas de Windows para respaldo, health check y
mantenimiento; el simulacro de restore es opt-in).

## 4. Unidad 7

### F-U7-1 · El SQL equivalente no corre sobre el esquema publicado — Alta · Documentado + corregido

**Qué se encontró.** `consultas_postgresql.sql` usa cuatro identificadores que
no existen en `schema.sql`:

| En el script | En `schema.sql` |
|---|---|
| `usuario` | `cliente` |
| `pedido.usuario_id` | `pedido.cliente_id` |
| `pedido.total` | no existe: `SUM(cantidad * precio_unitario)` |
| `estado = 'TERMINADO'` | ENUM `PENDIENTE, EN_PREPARACION, ENTREGADO, CANCELADO` |

La nota de compatibilidad del script afirma que el catálogo validado llama
`usuario` a la entidad de clientes; el `schema.sql` del repositorio dice lo
contrario. El script se ejecutó contra la base de trabajo de U7, que tiene otro
catálogo y otros datos (10 pedidos), por lo que la paridad 7/7 y 4/4 **no es
reproducible** desde `schema.sql` + `seed.sql`.

**Decisión.** Se conserva `consultas_postgresql.sql` tal como se ejecutó (es la
evidencia de la práctica) y se agrega
`consultas_postgresql_corregidas.sql` con el catálogo real. Sobre el seed, las
dos consultas devuelven 1 fila:

- Estado: el ENUM real no tiene `TERMINADO`; se usa `ENTREGADO` → pedido 1,
  total $3.250,00.
- Producto 1: pedido 1 → $3.250,00.

La diferencia se explica en `informe_tp7.md` y en este documento. El informe
técnico consolidado (§6.4) la declara como limitación de reproducibilidad.

**Código corregido.** Ver el anexo A.

### F-U7-2 · `insertMany` sin transacción y `drop()` previo — Media · Documentado

El script hace `db.pedidos.drop()` y después inserta 10 documentos en un
`insertMany` sin sesión. Si el proceso se corta entre el `drop` y el `insert`,
la colección queda vacía: no hay atomicidad entre la limpieza y la carga.

**Recomendación.** Cargar en `pedidos_staging`, validar el conteo y hacer
`renameCollection` con `dropTarget: true`. Para 10 documentos el riesgo es
bajo, pero el patrón no escala. Se documenta en el informe U7.

### F-U7-3 · PII en el código fuente — Media · Documentado

El seed embebido incluye `email` y `telefono` con formato real
(`juan@x.com`, `2611234567`) para Juan Pérez, María López, etc. Son datos
inventados, pero el código no lo declara y el repositorio es público.

**Recomendación.** Usar `@example.test` y teléfonos `000-0000000`, o generar el
seed desde el `seed.sql` real con un script de anonimización (mismo criterio que
`sql/usuario_anon.sql`). No se modificó para no invalidar la salida ya
presentada en el informe U7.

### F-U7-4 · Dinero en `double` — Baja · Documentado

El validador admite `["double", "decimal", "int"]` para `precio_unitario`,
`subtotal` y `total`. Para importes, `Decimal128` evita el error de
representación binaria. Al ser un snapshot de lectura y con dos decimales, el
riesgo práctico es bajo; se documenta.

### F-U7-5 · Proyección 4.a incompleta — Baja · Corregido

El comentario dice que se proyectan «identificador, estado, fecha y total», pero
la proyección es `{ _id, pedido_id, estado, total }`: falta `fecha`. Se corrigió
el comentario en `consultas_mongodb.js` para que describa lo que hace el código.

## 5. Unidad 8

### F-U8-1 · `precio REAL` para dinero — Alta · Corregido

`REAL` es punto flotante binario: no representa centavos de forma exacta y
acumula error en sumas. Se pasó a `precio_centavos INTEGER` con tablas `STRICT`
y `CHECK` de no negativos. Evidencia: `movil/schema_sqlite.sql`, casos C1 y C4.

### F-U8-2 · Borrado físico en la caché — Alta · Corregido

Cuando el servidor daba de baja un producto, la IA proponía borrar la fila de
`producto_cache`. Eso rompe la FK de `item_borrador` y borra el motivo del
rechazo. Se corrigió a baja lógica local (`eliminado = 1`, `disponible = 0`);
el catálogo disponible la excluye y C4 conserva la lápida.

### F-U8-3 · Reevaluación de solicitudes resueltas — Media · Corregido

El semáforo actualizaba todas las solicitudes, incluidas las ya aprobadas,
cada vez que se ejecutaba. Ahora solo evalúa `PENDIENTE`; `evaluado_en` no
cambia al repetir (C6).

### F-U8-4 · Booleanos `0/1` en el CSV — Media · Corregido

psql exporta `t/f`. El script los trata como texto en `snapshot_servidor` y los
normaliza con `CASE` al cargar `producto_cache`. Verificado en C1 y C4.

### F-U8-5 · Índice sobre `detalle_pedido(cantidad)` — Baja · Rechazado

Se probó el índice: el plan de la agregación sigue siendo `Seq Scan` porque el
predicado no filtra por `cantidad`. Se descartó con el plan real como evidencia
(`movil/evidencias/code_review_db.txt`).

## 6. Lo que está bien y conviene conservar

- **U4:** `SAVEPOINT`/`ROLLBACK TO` para demostrar anomalías sin ensuciar el
  esquema; verificación de FD2 en los datos **antes** de migrar (aborta en vez
  de resolver con `DISTINCT`); cubo con PK natural y granularidad explícita; y,
  tras la corrección F-U4-4, vista de compatibilidad que reúne por la clave de
  `responsable_deposito` y contraejemplo explícito de la variante con pérdida.
- **U5:** permisos por columna, `default deny`, hash del fragmento de log y
  distinción explícita entre auditoría nativa y `pgaudit`.
- **U6:** restauración en base descartable, conteos por tabla y validación de
  integridad posterior; el respaldo nunca reemplaza la base principal.
- **U7:** índice único sobre `pedido_id`, índice multikey declarado y validador
  `$jsonSchema` con ENUM; el dictamen híbrido está fundamentado.
- **U8:** tablas `STRICT`, montos en centavos, `PRAGMA foreign_keys = ON`,
  verificación de que la tablet no escribe en el servidor.

## Anexo A — `consultas_postgresql_corregidas.sql`

Archivo completo:
`Trabajo Practico - Unidad 7/consultas_postgresql_corregidas.sql`.

```sql
-- Equivalente a MongoDB 4.b sobre el catálogo real (cliente / cliente_id).
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
 ORDER BY p.id;

-- Equivalente a MongoDB 4.c: pedidos con producto_id = 1.
SELECT p.id AS pedido_id,
       p.fecha,
       p.estado,
       (SELECT COALESCE(SUM(d.cantidad * d.precio_unitario), 0)::numeric(12,2)
          FROM detalle_pedido d WHERE d.pedido_id = p.id) AS total
  FROM pedido p
 WHERE EXISTS (SELECT 1 FROM detalle_pedido dp
                WHERE dp.pedido_id = p.id AND dp.producto_id = 1)
 ORDER BY p.id;
```

Resultado esperado sobre `seed.sql` (derivado de las 5 líneas cargadas, no
ejecutado en esta sesión por no disponer de la contraseña del motor): 1 fila en
cada consulta (pedido 1, $3.250,00). La equivalencia con MongoDB se mantiene en
semántica; los conteos cambian porque el seed publicado tiene 3 pedidos, no los
10 de la base de trabajo de U7.

## Anexo B — Cómo se revisó

```powershell
# Contraste de identificadores contra el esquema publicado
Select-String -Path schema.sql -Pattern "CREATE TABLE|CREATE TYPE|cliente_id|total"

# Conteos de la migración y de las consultas
mongosh "mongodb://localhost:27017/foodstore" --eval "db.pedidos.countDocuments()"
mongosh "mongodb://localhost:27017/foodstore" --eval "db.pedidos.getIndexes()"
```
