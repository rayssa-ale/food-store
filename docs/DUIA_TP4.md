# DUIA — TP4: Reportes analíticos asistidos por IA (Food Store)

**Materia:** Base de Datos II — UTN · **Proyecto:** Food Store · **Fecha:** 22/09/2026

## Herramientas usadas

| Herramienta | Uso |
|---|---|
| **OpenCode** (CLI de IA, modelo *big-pickle) | Generación de las consultas analíticas T1–T5, interpretación de los planes reales, propuesta de índices/vistas materializadas y generación de la segunda versión de cada consulta para verificar equivalencia. |
| **PostgreSQL 18** (local) | Motor donde se midieron los planes y se verificaron las equivalencias (`food_store_tp3`, 50k productos / 200k pedidos / 500k líneas, de TP3). |
| **psql** (CLI) | `EXPLAIN (ANALYZE, BUFFERS)`, `ANALYZE`, `EXCEPT`, MVs e índices de verificación. |
| **Python runner** (`run_explain_tp4.py` / `_opt.py`) | Correr EXPLAIN sobre `sql/queries_tp4.sql` / `_opt.sql` y archivar los planes en `docs/planes4/`. |
| **Git + gh** | Versionado y publicación en el repositorio `rayssa-ale/food-store`. |

## Para qué se usó la IA y con qué prompts/specs

| Uso | Prompt / especificación aplicados |
|---|---|
| Consultas analíticas (Parte 1) | «Traé 5 reportes analíticos reales que crucen 3+ tablas con joins, agregación, funciones de ventana y subconsultas correlacionadas» → `sql/queries_tp4.sql` (T1 facturación por categoría/mes; T2 top-3 por categoría; T3 top-50 pedidos; T4 clientes que compran en todas las categorías; T5 facturación mensual de frecuentes con running total). |
| Optimización (Parte 1) | Se pasaron los **planes reales** con el pedido «justificá cada optimización por el nodo exacto que ataca; si el índice no es la palanca correcta, decilo». Salida: OPT-T1 (MV por categoría/mes), OPT-T2 (ajuste de work_mem, no índice), OPT-T3 (reescritura agregar-primero), OPT-T4 (índice covering, hipótesis a medir), OPT-T5 (MV de cliente/mes) y OPT-T5-A **(rechazada)**. |
| Lectura crítica (Parte 2) | «Explicá en lenguaje natural este plan multi-join» → se contrastó afirmación por afirmación con los nodos textuales; 5 de 6 afirmaciones resultaron falsas o parciales. |
| Equivalencia (Parte 3) | «Dadas estas 2 specs precisas (ranking con RANK por gasto; productos sobre el promedio de su categoría), generá el SQL y una versión alternativa con la MISMA semántica» → verificado con EXCEPT. |
| Competencia (Parte 4) | «Optimizá esta consulta fija (joins + agregación + ventana) sobre la copia» → MV + índice de soporte, verificado ×3.5. |

## Verificación (regla del TP: la IA propone, el motor decide)

1. **Parte 1 (análisis):** T1 540.832→**0.293 ms (×1846, MV)** · T2
   3096.592→**725.510 ms (×4.3, work_mem 256 MB de sesión; 64 MB no ayudó)** ·
   T3 791.681→**485.145 ms (×1.63, reescritura)** · T4 553.184→546.758 ms **sin
   mejora aunque el índice covering SÍ se usó (Index Only Scan)** — documentado ·
   T5 825.829→**236.047 ms (×3.5, MV)** ✔ Tabla completa en `docs/informe_analiticas_tp4.md`.
2. **Parte 2 (lectura crítica):** cada afirmación contrastada con nodos textuales
   del plan (inversión de lado externo/interno del Nested Loop, qué cachea el
   Memoize, cost ≠ tiempo real, etc.) ✔
3. **Parte 3 (equivalencia):** ESPEC(a): la "alternativa sin ventana" con
   `COUNT(DISTINCT total)` resultó **NO equivalente — EL EXCEPT LA DESTAPÓ**:
   `A - B = 19.743` filas (implementaba `DENSE_RANK`, no `RANK`); corregida a
   `COUNT(*)` de filas mayores → **0/0** env ambas direcciones. ESPEC(b):
   subconsulta correlacionada vs `AVG OVER(PARTITION BY categoria_id)` →
   `filas_A=filas_B=50.006`, `si_A=si_B=25.046`, **0/0** ✔ (`sql/equivalencias_tp4.sql`).
4. **Parte 4 (competencia):** T5 fija y su MV, ×3.5, plan real en
   `docs/planes4/`, registro en `docs/registro_competencia_tp4.md` ✔

## Revisión humana aplicada

- Cada propuesta se justificó por el **nodo exacto** del plan real antes de
  aplicarse (Sort externo a disco, batches de HashAggregate, doble
  materialización de CTE, lookups repetidos); ninguna se aplicó porque lo dijera
  la IA.
- Las mediciones vienen de corridas **en caliente** de `EXPLAIN (ANALYZE,
  BUFFERS)`, transcriptas textuales a `docs/planes4/*.txt`.
- La reescritura de T3 y las MVs de T1/T5 se verificaron con **EXCEPT en ambas
  direcciones** contra el conjunto completo de resultados (0 filas), no por
  inspección.
- El caso OPT-T5-A (rechazado por cambio de semántica, 46.322 vs 10.211 filas)
  se documentó como ejemplo de decisión adversa a la propuesta de la IA.
- Trabajo sobre la **copia** `food_store_tp3` (protocolo_seguridad.md; backup
  previo `respaldos/food_store_tp3_20260922_antes_tp4.sql`); las
  optimizaciones quedan en `sql/optimizaciones_tp4.sql`, no en `schema.sql`.