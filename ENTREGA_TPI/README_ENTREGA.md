# ENTREGA TPI — Food Store (entrega parcial, Unidades 1–3)

Qué presentar y en qué orden. Cada archivo acredita los objetivos de la
cátedra; el cruce completo está en `checklist_TPI.md`.

## 0. Documentos que abren la entrega

| Archivo | Rol |
|---|---|
| `informe_tecnico_TPI.md` | Resumen por unidad (qué/probado/resultados/optimizaciones/IA) |
| `checklist_TPI.md` | Los 9 objetivos → evidencia → cómo verificarlos |
| `evidencia_ejecucion.md` | **Capturas reales del motor** (salidas de verificación, planes EXPLAIN antes/después, mensajes R8–R10) |
| `duia.md` | Declaración de uso de IA (bitácora de sesiones) |
| `TPI_Food_Store_EntregaParcial.pdf` | Consolidado en un solo PDF (incluye la evidencia) |

## 1 · Unidad 1 — Integridad, transacciones y concurrencia

`01_modelado_y_ddl/` + `02_integridad_concurrencia/`

- `01_modelado_y_ddl/desarrollo_TP1.pdf` y `diagrama_ER.png` — modelo ER,
  pasaje a relacional (1:N y N:M con `detalle_pedido`) y normalización a
  BCNF con dependencias funcionales (objetivos **1–3**).
- `schema.sql` — DDL completo: ENUM, TIMESTAMPTZ, IDENTITY, PK/FK (RESTRICT),
  UNIQUE, CHECK e índices; soft delete con `activo` (objetivos **4, 7, 9**).
- `seed.sql` — datos iniciales para probar.
- `restricciones.sql` + `pruebas_validas_restricciones.sql` +
  `casos_invalidos_restricciones.sql` + `evidencia_restricciones_TPI.sql`
  (del repo, `sql/`) — reglas R8–R10 con triggers PL/pgSQL y su demostración
  en el motor con SAVEPOINT/ROLLBACK (objetivo **7**).
- `informe_concurrencia.md` y `ejercicio_lectura_critica.md` — atomicidad,
  COMMIT/ROLLBACK, niveles de aislamiento (READ COMMITTED vs REPEATABLE READ)
  y control de concurrencia con 2 sesiones (objetivo **8**).

## 2 · Unidad 2 — Optimización de consultas

`03_optimizacion/`

- `carga_masiva.sql` — datos masivos (50 k productos, 20 k clientes,
  200 k+ pedidos, 512 k+ líneas) para planes no triviales.
- `queries.sql`, `queries_tp4.sql`, `queries_tp4_opt.sql`, `equivalencias_tp4.sql`,
  `optimizaciones_tp4.sql` — JOIN, agregación, subconsultas, GROUP BY/HAVING
  y funciones de ventana (objetivo **5**); versiones optimizadas por nodo
  (MV, work_mem, reescritura).
- `planes/` — planes `EXPLAIN (ANALYZE)` antes/después de T1–T5 (evidencia).
- `informe_analiticas_tp4.md`, `informe_equivalencias_tp4.md`,
  `registro_competencia_tp4.md` — resultados (T1 ×1.846, T2 ×4,3, T3 ×1,63,
  T5 ×3,5; Q6 ×42) y equivalencias EXCEPT 0 filas.

## 3 · Unidad 3 — Índices, vistas y objetos programables

`04_indices_vistas_objetos/`

- `indices.sql` + `specs/` — índices justificados por plan previo, incluido
  parcial `WHERE stock < 50` y descartes D1/D2.
- `views.sql` + `verificacion_views.sql` — 4 vistas (3 reportes + 1 seguridad
  sin `telefono`), equivalencia EXCEPT 0/0.
- `materializadas.sql` + `verificacion_materializada.sql` — MV con índice
  único y `REFRESH CONCURRENTLY`.
- `procedimientos.sql` + `prueba_procedimientos_TPI.sql` — funciones PL/pgSQL,
  función JSONB, procedimiento con `CALL` y trigger con tabla de transición
  (objetivo **6** + características PostgreSQL 16+).
- `planes5/`, `informe_mediciones.md` — mediciones A1 ×1,6 / A2 ×30,4 / A3 ×2,
  costo de escritura +1,4 % y MV ×41.000.

## Cómo verificar en el motor (PostgreSQL 18, copia de trabajo)

```powershell
$env:PGPASSWORD = '<contraseña>'
$psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'
& $psql -U postgres -h localhost -d food_store_tp5 -f schema.sql
& $psql -U postgres -h localhost -d food_store_tp5 -f seed.sql
& $psql -U postgres -h localhost -d food_store_tp5 -f restricciones.sql
& $psql -U postgres -h localhost -d food_store_tp5 -f indices.sql
& $psql -U postgres -h localhost -d food_store_tp5 -f views.sql
& $psql -U postgres -h localhost -d food_store_tp5 -f verificacion_views.sql
& $psql -U postgres -h localhost -d food_store_tp5 -f materializadas.sql
& $psql -U postgres -h localhost -d food_store_tp5 -f verificacion_materializada.sql
& $psql -U postgres -h localhost -d food_store_tp5 -f procedimientos.sql
& $psql -U postgres -h localhost -d food_store_tp5 -f prueba_procedimientos_TPI.sql
```

Para recrear la base masiva desde cero usar `carga_masiva.sql` (ver TP3).