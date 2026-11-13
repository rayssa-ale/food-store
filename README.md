# FOOD STORE — Proyecto integrador · Base de Datos II (UTN)

Repositorio del equipo G. Cada TP tiene su **carpeta de entrega** (`TP1/` … `TP5/`)
con copias y PDF, y su historial de commits (flujo Kiro → OpenCode → el motor
decide). El código fuente vive en la raíz y en `sql/`.

## Índice de trabajos prácticos

| TP | Carpeta | Qué entrega | Commits clave |
|---|---|---|---|
| **TP1** — Modelo, normalización y DDL | `TP1/` (+ zip `Alejo_Rayssa_equipoG_TP1.zip`) | `schema.sql`, diagrama ER, `desarrollo_TP1.pdf`, DUIA | `450bb0c`, `1050b89` |
| **TP2** — Integridad y concurrencia | `TP2/` | restricciones/triggers (R8–R10), informe de concurrencia, lectura crítica, `TP2_Food_Store.pdf` | `38e9d75`, `df6b0fe`, `ff8372c` |
| **TP3** — Optimización: filtros, índices, planes | `TP3/` | carga masiva, queries, optimizaciones, equivalencias EXCEPT, competencia ×42, DUIA, `TP3_Food_Store.pdf` | `0a2b1d8`, `352e67a`, `f09a3e1`, `a94cee0` |
| **TP4** — Analíticas: joins, agregación, ventana | `TP4/` | queries_tp4, MVs T1/T5, lectura crítica, equivalencias EXCEPT, competencia ×3.5, DUIA, `TP4_Food_Store.pdf` | `57c1529`, `b073fba`, `c9f64cd` |
| **TP5** — Índices, vistas y vistas materializadas | `TP5/` | índices (×1.6 / ×30 / ×2), vistas + seguridad, MV ×41.000, `informe_mediciones.md`, `duia.md`, `TP5_Food_Store.pdf` | `a3f3844`, `ed24029`, `b73529e`, `44a74b1`, `edd0abc` |
| **TP6** — Unidad 4: FNBC y desnormalización controlada | `TP6/` | `tp_fnbc_control_lote.sql`, `tp_desnormalizacion_top_categorias.sql`, `TP6_Food_Store.pdf` | `b2bde0d`, `aa59180` |
| **U5** — Seguridad: roles, auditoría y anonimización | `sql/`, `docs/`, `docs/kiro_roles_spec/` | roles y permisos, auditoría nativa, simulacro de incidente, anonimización, logs e informes | `19690c9`, `3aa729d`, `aeb97dc`, `aab0868`, `bc97b80` |
| **U6** — Mantenimiento, respaldo y recuperación | `TP6/`, `TP6/sql/` | SPEC, backup/restore, health check, maintenance, `informe_u6.pdf`, anexo de evidencias | `4e02112` |
| **U7** — NoSQL: MongoDB vs PostgreSQL | `Trabajo Practico - Unidad 7/` | migración, consultas cruzadas, informes HTML/PDF | `f517c98` |
| **U8** — Food Store en la feria: SQLite + semáforo | `movil/`, `docs/` | schema/pruebas/semaforo SQLite, snapshot CSV, db, `informe.pdf`, specs Kiro, bitácora y DUIA | `4b97f27`, `c6837c7`, `46a6634` |
| **Segunda entrega (U4–U8)** | `SEGUNDA_ENTREGA/` | informe técnico único + PDF, checklist de 14 objetivos, code review y índice de la entrega | ver `git log -- SEGUNDA_ENTREGA` |

Historial completo: `git log --oneline` (cada commit describe su pieza y su evidencia).

---

## Segunda entrega (Unidades 4 a 8)

`SEGUNDA_ENTREGA/` reúne los documentos de cierre que integran U4–U8:

- `informe_tecnico_segunda_entrega.md` / `.pdf` — informe único con resultados
  verificables, condiciones de reproducción, riesgos y deuda.
- `checklist_segunda_entrega.md` — los 14 objetivos con evidencia y forma de
  verificarlos.
- `code_review_segunda_entrega.md` — hallazgos, severidad y decisión sobre todos
  los scripts (incluye el SQL corregido de U7).
- `README_ENTREGA.md` — orden de lectura y mapa de archivos.

La DUIA consolidada está en `docs/DUIA.md` y la bitácora de IA en
`BITACORA.md`. Las specs de Kiro de U4 (con plan de reversión) están en
`docs/kiro_u4/`.

> Limitación declarada: el SQL original de U7 usa un catálogo (`usuario`,
> `pedido.total`, `'TERMINADO'`) que no coincide con el `schema.sql` publicado.
> Se conserva como evidencia de lo ejecutado y se agrega
> `Trabajo Practico - Unidad 7/consultas_postgresql_corregidas.sql`, que sí corre
> sobre `schema.sql` + `seed.sql`.

---

## U8 (Unidad 8): Food Store en la feria

La tablet trabaja sin señal: guarda un catálogo en SQLite, arma borradores y
los somete a un semáforo contra una instantánea de PostgreSQL. **El móvil
propone, el servidor dispone**: `SIMULADO_APROBADO` no es una venta y la tablet
nunca cambia stock ni precios del servidor.

### Orden para crear todo desde cero

```powershell
$env:PGPASSWORD = '<contraseña>'
$psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'

# 1. Copia de trabajo (no tocar foodstore)
# createdb -U postgres -T foodstore foodstore_u8

# 2. Vista de instantánea y CSV (50.006 productos)
& $psql -U postgres -d foodstore_u8 -f movil/v_snapshot_movil.sql
& $psql -U postgres -d foodstore_u8 -f movil/exportar_snapshot.sql
& $psql -U postgres -d foodstore_u8 -f movil/verificacion_servidor.sql
```

3. Abrir `movil/foodstore_movil.db` con **DB Browser for SQLite** (o `sqlite3`)
   y ejecutar `movil/schema_sqlite.sql`.
4. Importar `movil/servidor_snapshot.csv` en la tabla `snapshot_servidor`
   (CSV, cabecera incluida, `--skip 1`).
5. Ejecutar `movil/semaforo.sql`: normaliza `t/f`, actualiza `producto_cache` y
   evalúa solo solicitudes `PENDIENTE`.
6. Ejecutar `movil/pruebas_sqlite.sql` para C1, borrador con `COMMIT`,
   `ROLLBACK` y C7. Los dos `INSERT` inválidos de C7 deben fallar y dejar 0
   filas; no se corrige el error: se demuestra el rechazo.
7. Para los casos C2–C6, repetir el ciclo: borrador → cambio en
   `foodstore_u8` → nuevo CSV → importar → `semaforo.sql`.

| Evidencia | Resultado |
|---|---|
| Snapshot | 50.006 productos, 2,96 MB, `fecha_copia` 2026-11-12 |
| C1 / C7 | catálogo sin servidor; `COMMIT` deja 1 borrador, `ROLLBACK` 0; cantidad 0 y producto inexistente rechazados por `CHECK` y `FK` |
| C2 | `CONFLICTO`; al aceptar el precio, nueva solicitud `SIMULADO_APROBADO` |
| C3 | `RECHAZADO` por stock insuficiente (500 > 106) |
| C4 | `RECHAZADO` por baja lógica; la fila de caché queda con `eliminado = 1` |
| C5 | `SIMULADO_APROBADO` sin cambios |
| C6 | UUID repetido → error de PK; repetir el semáforo no reevalúa |
| PostgreSQL | pedidos 227.009 y stock total 4.989.376 sin cambios; solo baja lógica del producto 3 |
| Code review | 4 hallazgos con decisión; índice `detalle_pedido(cantidad)` descartado por plan real |

Entregables: `movil/schema_sqlite.sql`, `movil/pruebas_sqlite.sql`,
`movil/semaforo.sql`, `movil/servidor_snapshot.csv`,
`movil/foodstore_movil.db`, `docs/informe.pdf`, `docs/kiro/`,
`docs/bitacora_ia.md` y `docs/DUIA.md`. Evidencias en `movil/evidencias/`.

---

## U6 (Unidad 6): Mantenimiento, respaldo y recuperación

Laboratorio sobre `foodStore`, con restauración descartable en
`foodstore_restore_test`. La base principal nunca se elimina ni se reemplaza.

```powershell
# ejecutar desde la raíz del repo
.\TP6\backup_foodstore.ps1
& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -d foodStore -f TP6\sql\health_check.sql
& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -d foodStore -f TP6\sql\maintenance.sql
.\TP6\restore_test.ps1
```

| Evidencia | Resultado |
|---|---|
| Respaldo `pg_dump -Fc` | `foodStore_2026-10-30_172759.dump`, 32,62 KB |
| Health check | conexiones, bloqueos y ratio commits/rollbacks dentro del umbral |
| Mantenimiento | `VACUUM (VERBOSE, ANALYZE)` sin `VACUUM FULL`; `n_dead_tup = 0` |
| Restauración | RTO **6,18 s** (meta < 300 s), RPO **6 h 00 m 26 s** (meta < 24 h) |
| Validación | 4/5/12/11/20 filas restauradas, 0 inconsistencias lógicas |

Detalle y evidencias: `TP6/SPEC_U6.md`, `TP6/informe_u6.pdf` y
`TP6/anexo_evidencias_u6.pdf`.

---

## TP6 (Unidad 4): FNBC y desnormalización controlada

Dos herramientas de la Unidad 4 aplicadas sobre Food Store, con la misma
regla en ambas: ninguna decisión de diseño se toma por intuición.

**Parte 1 — FNBC sobre `control_lote_almacen`.** La DF
`{LoteID, DepositoID} → {ResponsableControlID}` no viola nada (su
determinante es la PK), pero `ResponsableControlID → DepositoID` sí: su
determinante no es superclave. El esquema tiene **tres** claves candidatas
sobre dos atributos y **ningún** atributo no primo, o sea que cumple 3FN y
no cumple FNBC — el caso donde las dos definiciones se separan. La
descomposición produce `responsable_deposito` + `control_lote`, ambas en
FNBC, con reunión sin pérdida por el criterio de superclave sobre
`DepositoID`. Las tres anomalías se demuestran con SQL dentro de savepoints.

**Parte 2 — desnormalización controlada del top 5 por día.** El plan de la
consulta de 4 tablas está dominado por `Parallel Seq Scan` sobre
`detalle_pedido`: lee ~549.529 filas para responder sobre ~31.372 líneas
del día. Se agrega `fact_venta_categoria_dia` (grano día × categoría)
mantenida por disparadores — camino caliente incremental para líneas,
camino frío con recálculo del día para cambios de alcance ancho — y el
panel pasa a leer 3 filas de 1 bloque.

```powershell
$env:PGPASSWORD = '<contraseña>'
$psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'

# copia de trabajo (protocolo de seguridad) + respaldo previo
# pg_dump -U postgres food_store_tp5 > respaldos/food_store_tp5_20261001_antes_tp6.sql
# createdb -U postgres -T food_store_tp5 food_store_tp6

# día corriente medible (la carga de TP3 siembra ~580 pedidos/día)
& $psql -d food_store_tp6 -f TP6/carga_dia_actual.sql

& $psql -d food_store_tp6 -v ON_ERROR_STOP=1 -f TP6/tp_fnbc_control_lote.sql
& $psql -d food_store_tp6 -v ON_ERROR_STOP=1 -f TP6/tp_desnormalizacion_top_categorias.sql
```

| Antes (4 tablas) | Después (cubo) |
|---|---|
| Parallel Seq Scan — ~549.529 filas, 5.004 buffers | Bitmap Index + Heap Scan — 3 filas, 6 buffers |
| **138,0 ms** (233,2 ms en frío) | **0,118 ms** |

Dos desvíos del enunciado, documentados en el script y en el informe: el
esquema real no tiene `eliminado` ni `subtotal` (la baja lógica es el ENUM
`estado_pedido` y el subtotal es `cantidad * precio_unitario`), y
`fecha = CURRENT_DATE` sobre un TIMESTAMPTZ devuelve 0 filas de los 12.269
pedidos de un día real — se usa predicado de rango. Sin esa corrección el
`EXPLAIN` mide un conjunto vacío.

Detalle, justificaciones y los dos planes de `EXPLAIN ANALYZE` completos:
`TP6/TP6_Food_Store.pdf`.

---

## TP5 (Unidad 3 · Semana 5): Índices, vistas y vistas materializadas

Trabajo integrador de **Base de Datos II (UTN)**. Continúa las Semanas 1 a 4
(`schema.sql`, `seed.sql` = `data.sql`, `queries.sql`) y agrega índices, vistas
y una vista materializada **sin modificar el modelo de datos**.

Estructura mínima pedida por la cátedra:

```
food-store/
├── schema.sql            (heredado, sin modificar)
├── seed.sql / data.sql   (heredado; el proyecto lo llama seed.sql)
├── queries.sql           (heredado en sql/)
├── sql/indices.sql       (nuevo — Parte A)
├── sql/views.sql         (nuevo — Parte B)
├── sql/materializadas.sql(nuevo — Parte C)
├── specs/                (especificaciones de Kiro, 11 archivos)
├── duia.md               (bitácora de uso de IA)
├── informe_mediciones.md (EXPLAIN ANALYZE antes/después, lectura y escritura)
└── README.md             (este archivo)
```

## Prerrequisitos

- PostgreSQL 18 local, usuario `postgres`. (psql/pg_dump no están en el PATH:
  usar `C:\Program Files\PostgreSQL\18\bin\...`.)
- Base masiva: `food_store_tp3` ya existente (Semanas 3-4) o recargar con
  `schema.sql` + `seed.sql`.

## Cómo reproducir (sobre la copia de trabajo)

```powershell
$env:PGPASSWORD = '<contraseña>'
$psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'

# 1. Copia de trabajo (protocolo de cátedra) + respaldo previo
#    pg_dump -U postgres food_store_tp3 > respaldos/<fecha>.sql
#    createdb -U postgres -T food_store_tp3 food_store_tp5

# 2. Parte A — índices y mediciones
#    a) planes ANTES:  python (Temp)\run_explain_tp5.py food_store_tp3 antes 3   (o EXPLAIN a mano)
#    b) escritura ANTES: & $psql -d food_store_tp5 -f sql\prueba_escritura_antes.sql
#    c) crear índices:   & $psql -d food_store_tp5 -f sql\indices.sql
#    d) planes DESPUÉS:  python (Temp)\run_explain_tp5.py food_store_tp5 despues 3
#    e) escritura DESPUÉS: & $psql -d food_store_tp5 -f sql\prueba_escritura_despues.sql

# 3. Parte B — vistas
& $psql -d food_store_tp5 -f sql\views.sql
& $psql -d food_store_tp5 -f sql\verificacion_views.sql      # EXCEPT 0/0

# 4. Parte C — vista materializada
& $psql -d food_store_tp5 -f sql\materializadas.sql
& $psql -d food_store_tp5 -f sql\verificacion_materializada.sql
```

Los runners usan psycopg2 y archivan los planes en `docs/planes5/`.
Las queries medidas están en `sql/queries_tp5.sql` (A1-A3) y la prueba de
escritura en `sql/prueba_escritura_{antes,despues}.sql`.

## Resultados en una línea

- **Índices:** A1 ×1.6 · A2 (parcial) **×30.4** · A3 ×2 — planes en `docs/planes5/`.
- **Escritura:** pedido +1.4 % (costo real del índice compuesto); detalle_pedido
  no varía (los índices nuevos no lo tocan).
- **Descartes:** `detalle_pedido(cantidad)` (el plan sigue Seq Scan: verificado)
  y `pedido(cliente_id, estado)` (redundante) — `specs/descartado_*.md`.
- **Vistas:** 4 vistas verificadas con EXCEPT 0/0; la de seguridad no expone
  `telefono`.
- **Materializada:** 905.8 ms → **0.022 ms (×41.000)**, con índice único para
  `REFRESH CONCURRENTLY`.

Detalle, justificaciones y planes textuales: `informe_mediciones.md`.

---

## Entrega parcial del TPI (Unidades 1–3)

- `docs/checklist_TPI.md` — los 9 objetivos de la entrega con su evidencia y
  cómo verificarlos.
- `informe_tecnico_TPI.md` — resumen por unidad: qué se implementó, cómo se
  probó, resultados y optimizaciones antes/después.
- `sql/procedimientos.sql` — funciones PL/pgSQL de negocio, función JSONB,
  procedimiento con `CALL` y trigger con tabla de transición (objetivo 6):
  ```powershell
  & $psql -d food_store_tp5 -f sql/procedimientos.sql
  & $psql -d food_store_tp5 -f sql/prueba_procedimientos_TPI.sql
  ```
- `duia.md` — bitácora de uso de IA de las sesiones.