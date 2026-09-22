# Informe de laboratorio — Analíticas con joins, agregación y ventana (TP4, Parte 1)

**Materia:** Base de Datos II — UTN · **Proyecto:** Food Store · **Fecha:** 22/09/2026
**Base:** `food_store_tp3` (50.006 productos, 20.003 clientes, 200.003 pedidos, 500.014 líneas)
**Flujo:** EXPLAIN (ANALYZE, BUFFERS) en caliente → plan real a la IA → propuesta por nodo → se lee y decide → se aplica → se re-mide. Todo lo que no mejora se documenta.

## Consultas analíticas medidas (`sql/queries_tp4.sql`, todas cruzan ≥3 tablas)

- **T1** facturación por categoría y mes (detalle+pedido+producto+categoria, ENTREGADO).
- **T2** top 3 productos por categoría según recaudación (detalle+producto+categoria, ventana ROW_NUMBER).
- **T3** top 50 pedidos por importe con cliente y líneas (pedido+cliente+detalle, no CANCELADO).
- **T4** clientes que compraron en todas las categorías (cliente+pedido+detalle+producto+categoria, subconsulta correlacionada).
- **T5** facturación mensual con acumulado de clientes frecuentes (pedido+detalle+cliente, ventana).

## 1.2 Tabla de resultados (Execution Time real en caliente)

| Consulta | Algoritmo de join (antes) | Cambio aplicado | Algoritmo de join (después) | Antes → Después (ms) | Mejora |
|---|---|---|---|---|---|
| **T1** fact cat/mes | Hash Join (detalle↔pedido) en paralelo + Hash Join ↔producto + Hash Join ↔categoria → Sort externo a disco (3,4 MB) para el GroupAggregate | **MV `mv_ventas_categoria_mes`** (materialización analítica): el sort+join sobre 500k líneas no se justifica para un reporte de 39 filas | — (la consulta lee la MV: Seq Scan de 39 filas, sin joins) | 540.832 → **0.293** | **×1846** ✔ |
| **T2** top3 por categoría | Hash Join (detalle↔producto) + Hash Join ↔categoria → **Sort externo 8.168 kB a disco** (2,4 s) previo al GroupAggregate + WindowAgg | **work_mem = 256 MB (sesión)** — no hay índice que reduzca un agregado de tabla completa; el cuello era el derrame del sort, verificado en el plan (`Sort Method: external merge Disk: 8168kB`) | Hash Join (igual) — no cambia el algoritmo; el sort pasa de external merge (disco) a quicksort (memoria) | 3096.592 → **725.510** | **×4.3** (rango medido 725–965) ✔ |
| **T3** top50 pedidos | **Nested Loop** (pedido↔cliente, con Memoize) sobre los ~167 mil pedidos + **Merge Join** (↔detalle, 500k líneas) + Incremental Sort de 12.645 grupos por cliente | Reescritura: **agregar detalle por pedido_id primero** y adjuntar el cliente solo a los 50 elegidos (`sql/queries_tp4_opt.sql`) — los montos viven en la línea, el join con clientes no necesita el 100 % | Merge Join (detalle↔pedido) + **Nested Loop solo sobre los 50 pedidos** del top (cliente: 50 loops, no 166.857) | 791.681 → **485.145** | **×1.63** ✔ |
| **T4** clientes todas las categorías | **Nested Loop Anti** de 3 niveles (por cliente → por pedido → por línea; 133.542 lookups a producto con filtro `categoria_id`, 400.626 buffers) | Índice covering `ix_producto_cat_cover ON producto (id) INCLUDE (categoria_id)` para dejar de tocar el heap en el lookup por línea | El índice se usa (Index Only Scan `ix_producto_cat_cover`) pero el plan sigue igual de costoso | 553.184 → 546.758 | **×1.0 — sin mejora**, se documenta: el cuello es el bucle correlacionado de 133k ejecuciones, no el heap de producto |
| **T5** mensual acumulado | Hash Join (detalle↔pedido, vía `ix_pedido_estado`) + Nested Loop cliente + **CTE materializada 2 veces a disco** y re-leída desde disco (216 ms) + Sort externo | MV `mv_fact_cliente_mes` (cliente, mes): el running total es métrica de dashboard, re-consultada; además se **descartó** una reescritura que parecía equivalente pero cambiaba la semántica (ver §1.3) | Hash Join/Scan sobre la MV (sin re-scanear 500k líneas ni materializado doble) | 825.829 → **236.047** | **×3.5** ✔ |

## 1.3 Criterio de aceptación (aplicado, y la equivocación que se destapó)

- **Se aceptaron** T1 (MV), T2 (work_mem), T3 (reescritura), T5 (MV): cada una se explica por un nodo concreto del plan y se confirmó con medición.
- **Se probó y rechazó OPT-T5-A**: mover `HAVING COUNT(*) >= 5` dentro de la CTE parecía equivalente, pero cambió el **filtro de borrado lógico/negocio**: pasó de "≥5 meses con ventas" a "≥5 líneas en un mes" → 46.322 filas (original) vs 10.211 (intento). Se detectó comparando conteos; la reescritura corregida sobre la MV preserva la semántica exacta (verificado EXCEPT 0/0).
- **Se aplicó pero no mejoró** T4 (índice covering): se documenta; el plan mostró que el índice sí se usa pero no es el cuello.
- **T2 — cambio de algoritmo de join:** el índice NO cambia el algoritmo (sigue Hash Join); el ajuste de `work_mem` cambia el nodo Sort (external merge → quicksort). Se documenta porque la mejora nació de un knob de entorno, no de un índice, y eso se explica en la defensa oral.

Planes completos (verbatim): `docs/planes4/*_antes.txt`, `docs/planes4/*_despues.txt` (T2 bajo work_mem: `T2_top3_categoria_despues_wmem.txt`).