# FOOD STORE — TP5 (Unidad 3 · Semana 5): Índices, vistas y vistas materializadas

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