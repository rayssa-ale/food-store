# DUIA — TP3: Optimización asistida por IA (Food Store)

**Materia:** Base de Datos II — UTN · **Proyecto:** Food Store · **Fecha:** 22/09/2026

## Herramientas usadas

| Herramienta | Uso |
|---|---|
| **OpenCode** (CLI de IA, modelo *big-pickle) | Propuesta de índices para los planes medidos, generación/reescritura de consultas y explicación de planes (después confrontada de forma crítica). |
| **PostgreSQL 18** (local) | Motor donde se midieron los planes (`food_store_tp3`, 50k productos / 200k pedidos / 500k líneas) y se verificaron las equivalencias. |
| **psql** (CLI) | Ejecución de `EXPLAIN (ANALYZE, BUFFERS)`, `ANALYZE`, índices y consultas de verificación. |
| **Python runner** (`run_explain.py`) | Correr EXPLAIN sobre `sql/queries.sql` y archivar los planes en `docs/planes/`. |
| **Git + gh** | Versionado y publicación en el repositorio `rayssa-ale/food-store`. |

## Para qué se usó la IA y con qué prompts/specs

| Uso | Prompt / especificación aplicados |
|---|---|
| Elección de consultas lentas | «Traé 4 consultas de negocio reales con JOIN/filtros/ORDER/GROUP sobre producto/pedido/detalle para medir con EXPLAIN ANALYZE (carta, historial por cliente, top productos, facturación y una consulta "a lo competencia" sin índice dedicado)» → `sql/queries.sql`. |
| Propuesta de optimización (parte 2) | Se pasaron los **planes reales** (nodo, cost, times) junto con el pedido «proponé índices/reescrituras, y justificá cada propuesta por el nodo exacto que ataca». Salida: OPT-1 (compuesto parcial), OPT-2 (covering), OPT-3 (estado). |
| Lectura crítica (parte 3) | «Explicá en lenguaje natural este plan EXPLAIN» → se comparó afirmación por afirmación con el plan (4 de 5 imprecisiones detectadas). El proceso de refutación de una hipótesis propia (OPT-3/Q4) también quedó registrado. |
| Generación de consultas equivalentes (parte 4) | «Dadas estas 2 specs en lenguaje natural, generá el SQL y una versión alternativa con la MISMA semántica». Se eligieron LEFT JOIN+COUNT vs subconsulta escalar, y HAVING+subconsulta vs CTE. Bugs de correlación (alias `d` vs `d2`) descubiertos por la **verificación EXCEPT en el motor**, no por la IA. |
| Desafío de la competencia (parte 5) | «Optimizá esta consulta fija sobre la copia» → índice compuesto parcial `(categoria_id, precio) WHERE activo`, verificado ×42. |

## Verificación (regla del TP: la IA propone, el motor decide)

1. **Parte 1 (datos):** conteos reales en `food_store_tp3` (50.006 / 20.003 /
   200.003 / 500.014) y `ANALYZE` ✔
2. **Parte 2 (optimización):** Q6_competencia 14.242 ms → **0.338 ms (×42)** ✔ ·
   Q1 ~1.19× sin cambio de plan ✔ documentada · Q3 ~1.09× marginal ✔ · Q4 sin
   mejora (hipótesis refutada) ✔ documentada — tabla en `docs/informe_optimizacion.md`.
3. **Parte 3 (lectura crítica):** cada afirmación de la IA contrastada con nodos
   textuales del plan (Sort Key, Index Cond, rows actuales, cost vs ms) ✔
4. **Parte 4 (equivalencia):** Espec 1 → 3 filas en ambas versiones; Espec 2 →
   9.088 filas en ambas; `(A) EXCEPT (B)` = 0 y `(B) EXCEPT (A)` = 0 en ambos
   casos ✔ (script `sql/equivalencias_consultas.sql`).
5. **Parte 5 (competencia):** plan base vs plan optimizado con EXPLAIN ANALYZE,
   ×42, registro en `docs/registro_competencia.md` ✔

## Revisión humana aplicada

- Cada propuesta de índice se leyó y justificó **antes** de aplicarse (qué nodo
  atacaba y por qué); ninguna se corrió "porque la IA lo dijo".
- Las mediciones provienen de corridas **en caliente** de `EXPLAIN (ANALYZE,
  BUFFERS)`, transcriptas textuales a `docs/planes/*.txt`.
- Las consultas equivalentes se validaron en el motor con EXCEPT en ambas
  direcciones (0 filas), no por inspección visual.
- Trabajo sobre la **copia** `food_store_tp3` (protocolo_seguridad.md); los
  índices de optimización quedan en `sql/optimizaciones.sql`, no en `schema.sql`.