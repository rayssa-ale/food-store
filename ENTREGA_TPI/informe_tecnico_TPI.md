# Informe técnico — Entrega parcial del TPI «Food Store»

**Base de Datos II · UTN · Equipo G · 22/09/2026 · Motor: PostgreSQL 18 (≥16) + PL/pgSQL**

Resumen de lo actuado en las Unidades 1–3 con el flujo de cátedra
**Kiro (specs) → OpenCode (IA) → el motor decide (evidencia)**. El checklist de
verificación por objetivo está en `docs/checklist_TPI.md` y la bitácora de uso
de IA en `duia.md`.

## Unidad 1 — Integridad, transacciones y concurrencia

### Qué se implementó
- Modelo ER → relacional → normalización a BCNF → DDL definitivo (`schema.sql`),
  con ENUM, `TIMESTAMPTZ`, `IDENTITY`, PK/FK con `ON DELETE RESTRICT`, `UNIQUE`
  (email, nombre de categoría, par de detalle), `CHECK` y 3 índices justificados.
- Reglas R8–R10 garantizadas por el motor con triggers PL/pgSQL
  (`sql/restricciones.sql`): transiciones de estado del pedido, stock suficiente
  con descuento atómico y precio de línea congelado.
- Protocolo de trabajo seguro sobre copia: `protocolo_seguridad.md`
  (copia → transacción → respaldo).

### Cómo se probó
- DDL: ejecución completa de `schema.sql` sobre una copia de trabajo, sin errores.
- Triggers: batería de casos **válidos** (INSERT/UPDATE lícitos dentro de la
  transacción, COMMIT final) e **inválidos** (cada uno en su transacción que se
  aborta y ROLLBACK); se verificó el mensaje de excepción de cada regla.
- Concurrencia: 4 escenarios reproducidos con **dos sesiones `psql`** simulando
  dos terminales (informe `docs/informe_concurrencia.md`).

### Resultados
- READ COMMITTED permite **lectura no repetible** (precio 1200→1300) y
  **fantasma** (COUNT 2→3); REPEATABLE READ los elimina con instantánea fija.
- Un `UPDATE` de la misma fila se **bloqueó 4,51 s** hasta el COMMIT de la otra
  sesión (mecanismo que evita la pérdida de la actualización); el conflicto se
  abortó con `40P01`.
- Los casos inválidos fueron rechazados por el motor con el mensaje de la regla
  correspondiente (R8 transición, R9 sobreventa, R10 precio congelado).

## Unidad 2 — Optimización de consultas

### Qué se implementó
- Carga masiva de datos para explotar planes no triviales
  (`sql/carga_masiva.sql` TP3): 50 k productos, 20 k clientes, 200 k pedidos +
  512 k líneas.
- 5 consultas analíticas de 3+ tablas (`sql/queries_tp4.sql`) y su versión
  optimizada por nodo (`sql/queries_tp4_opt.sql`): vista materializada,
  `work_mem`, reescritura y funciones de ventana.
- Equivalencias verificadas entre versiones distintas y entre funciones de
  ventana / subconsultas (`sql/equivalencias_tp4.sql`).

### Cómo se probó
- `EXPLAIN (ANALYZE, BUFFERS, TIMING)` antes/después por consulta, planes
  archivados en `docs/planes4/*.txt`; lecturas críticas de planes en
  `docs/ejercicio_lectura_critica_join.md` (inversión externa/interna del
  Nested Loop, Memoize que cachea cliente pero no pedidos, cost ≠ tiempo).
- Equivalencias con `EXCEPT` → 0 filas (parte del enunciado).

### Resultados (antes → después, best of)
| Consulta | Técnica | Antes | Después | Ganancia |
|---|---|---|---|---|
| T1 facturación por categoría/mes | MV `mv_facturacion_categoria_mes` | 1.101 ms | 0,6 ms | **×1.846** |
| T2 top 3 por categoría (window) | `work_mem` + plan | 125 s | 29 s | **×4,3** |
| T3 top 50 pedidos | reescritura alias | 78,1 ms | 47,9 ms | ×1,63 |
| T5 acumulado mensual por cliente | MV | 6.593 ms | 1.887 ms | **×3,5** |
| Q6 competencia (TP3) | índices propuestos por IA | — | — | **×42** |

Se **descartaron** propuestas de IA que no mejoraban o rompían equivalencia
(OPT-T5-A y la variante con `COUNT(DISTINCT)` que ocupaba DENSE_RANK: se detectó
por la diferencia 19.743 y se corrigió a `COUNT(*)`).

## Unidad 3 — Índices, vistas y objetos programables del motor

### Qué se implementó
- Índices con justificación de plan previo (`sql/indices.sql`, `specs/`),
  incluido un **índice parcial** para reposición de stock.
- 4 vistas (`sql/views.sql`): 3 de reporte + 1 **de seguridad** que oculta
  datos personales (no expone `telefono`).
- Vista materializada con índice único para `REFRESH CONCURRENTLY`
  (`sql/materializadas.sql`).
- **Nuevo en esta entrega:** funciones de negocio PL/pgSQL, función que produce
  **JSONB**, procedimiento invocado con **CALL** y trigger a nivel sentencia con
  **tabla de transición** (`sql/procedimientos.sql`).

### Cómo se probó
- Mediciones `EXPLAIN (ANALYZE)` antes/después (best of 3), prueba de **costo de
  escritura** (6.000 pedidos + 6.000 líneas) y descarte D1 de sobreindexación
  verificado en el motor (el plan seguía siendo Seq Scan).
- Vistas: equivalencia contra la consulta manual con `EXCEPT` → 0/0 en las 4 y
  verificación de que `v_cliente_contacto` no tiene `telefono`.
- MV: equivalencia 0/0, build y refresco concurrente; procedimientos/función/
  transición: `sql/prueba_procedimientos_TPI.sql` (CALL, funciones, auditoría).
- La **repetición de corridas** confirmó estabilidad (no single-shot).

### Resultados
| Ítem | Antes | Después | Diferencia |
|---|---|---|---|
| A1 pedidos del mes (`(fecha, estado)`) | 18,8 ms | 11,5 ms | ×1,6 |
| A2 stock bajo (índice parcial) | 10,4 ms | 0,34 ms | **×30,4** |
| A3 cliente por apellido (opclass) | 2,75 ms | 1,40 ms | ×2,0 |
| Escritura pedido (costo real) | 234,5 ms | 237,8 ms | +1,4 % |
| MV facturación ×41.000 | 905,8 ms | 0,022 ms | **×41.000** |
| Descartes | D1 `(cantidad)` y D2 `(cliente, estado)` | — | documentados en `specs/` |

Vista materializada: `REFRESH CONCURRENTLY` habilitado por índice único,
frecuencia justificada (corte mensual, 117 filas → refresco económico).

## Uso de herramientas de IA

- **IA usada:** solo **OpenCode** (la herramienta indicada por la cátedra), con
  el flujo de especificación de **Kiro**. No se utilizó ninguna otra herramienta
  de IA.
- **Decisión aceptadas** (con verificación en el motor): índices A1–A3, MVs T1/T5,
  reescritura de T3, procedimiento/funciones y trigger de transición propuestos
  por la IA y validados con EXPLAIN/equivalencia.
- **Decisiones descartadas:** OPT-T5-A (equivalencia), índice D1 `detalle(cantidad)`
  (el plan no cambiaba), D2 redundante, y la especificación inicial de la parte 3
  de TP4 que usaba `COUNT(DISTINCT)` como DENSE_RANK (corregida con `COUNT(*)`).
- **Verificación humana:** cada script se aplicó sobre la **copia de trabajo**
  dentro de `BEGIN/COMMIT` o `BEGIN/ROLLBACK`, sin tocar las bases en uso; los
  planes y números provienen de corridas reales del motor, no de estimaciones.

> Reproducción completa y comandos: `README.md`. Evidencia por objetivo:
> `docs/checklist_TPI.md`. Bitácora de sesiones IA: `duia.md`.