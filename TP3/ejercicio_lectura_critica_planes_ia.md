# Ejercicio de lectura crítica: planes de ejecución interpretados por IA (TP3, Parte 3)

**Materia:** Base de Datos II — UTN · **Proyecto:** Food Store
**Base:** `food_store_tp3` (50.006 productos, 200.003 pedidos, 500.014 líneas)

## Contexto

Tras la Parte 2, el plan post-optimización de la consulta de la competencia
(`Q6_competencia`, `docs/planes/Q6_competencia_despues.txt`) se le pasó a la
IA para que lo **explicara en lenguaje natural**. El ejercicio consiste en
confrontar esa explicación con el plan real: la IA es buena resumiendo, pero
puede **plantar certezas falsas** (confundir cost estimado con tiempo, inventar
claves de orden, sobrevender el efecto de un índice). Tabla de afirmaciones con
evidencia textual del plan.

## 3.1 Explicación generada por la IA (textual, sobre Q6_competencia después)

> "El plan usa un `CREATE INDEX` nuevo sobre `(categoria_id, precio)`. Con el
> índice la consulta ya no toca la tabla: hace un Index Scan que recorre la
> categoría 2 **entera** y descarta sobre la marcha los precios fuera del
> rango. Después un Incremental Sort **ordena las 8.882 filas** por nombre y el
> Limit deja las 100 primeras. El costo estimado es de 1.33 a 44.40, es decir
> que el plan **cuesta 44 milisegundos**; el Execution Time de 0.338 ms lo
> confirma. Como se leen exactamente las 100 filas del LIMIT, la mejora
> respecto de antes (14 ms) es de unos 42x, que es lo que esperábamos."

## 3.2 Análisis crítico contra el plan real

| # | Afirmación de la IA | ¿Correcta? | Corrección · evidencia textual del plan |
|---|---|---|---|
| 1 | "El Incremental Sort ordena las 8.882 filas por **nombre**" | ✗ | La clave de orden es **precio, id**, no nombre: `Sort Key: precio, id`. Además 8.882 es la **estimación** del optimizador, no lo ordenado: `Full-sort Groups: 4 · Sort Method: quicksort` y solo se leyeron **103 filas**. |
| 2 | "Recorre la categoría 2 **entera** y filtra sobre la marcha" | ✗ | El rango de precio está en el `Index Cond: ((categoria_id = 2) AND (precio >= '600') AND (precio <= '3000'))`. El árbol del índice salta directo al rango (`Index Searches: 1`), no recorre todos los productos de la categoría. |
| 3 | "El cost estimado (44.40) son 44 **milisegundos**" | ✗ | El `cost` de EXPLAIN es una **unidad adimensional** (I/O + CPU ponderados), no tiempo. Execution Time de 0.338 ms no "confirma" un costo en ms; son magnitudes distintas. |
| 4 | "Se leen exactamente las 100 filas del LIMIT" | Parcial | El Index Scan produjo **103 filas** (`rows=103.00`) y el Limit cortó a 100. El Incremental Sort lee filas extra del grupo para garantizar el orden determinístico `precio, id`. |
| 5 | "La mejora 14 ms → 0.338 ms es ~42x" | ✔ | Correcto: 14.242 ms (antes, bitmap) → 0.338 ms (después, index scan). El único dato verificable de la explicación. |

**Conclusión de la lectura crítica:** 4 de 5 afirmaciones eran parcial o
totalmente incorrectas; solo la cuenta de mejora era cierta. La lección para el
informe: **nunca citar la explicación de la IA como si fuera el plan** — toda
afirmación se cita con su nodo/valor textual de `EXPLAIN (ANALYZE, BUFFERS)`.

## 3.3 Segundo caso: refutación de una hipótesis de la IA (Q4, OPT-3)

La IA propuso `ix_pedido_estado` para Q4 con la hipótesis: "el filtro
`estado = 'ENTREGADO'` descarta ~50% de pedidos en un Seq Scan; indexando el
estado el scan se acorta". La lectura crítica del plan final lo refuta:

| Hipótesis de la IA | Evidencia del plan real que la refuta |
|---|---|
| "El cuello es el filtro de estado sobre pedido" | El plan muestra que el costo **dominante** es el agregado sobre 500.014 líneas: `HashAggregate` en `Batches: 5` con **spill a disco** (`Disk Usage: 224kB`), Hash Join sobre `detalle_pedido` (Parallel Seq Scan, `rows=166671` por worker) y Gather. El filtro de pedido (`Rows Removed by Filter: 49977` c/worker) es un costo menor comparado. |
| "El índice de estado va a recortar la medición" | Medido tras aplicar OPT-3: 431.486 ms → 491.502 ms (sin cambio, dentro del ruido). El plan no eligió el índice nuevo ni podía: el agregado de 500k filas no se reduce con un índice de estado. |

**Regla aplicada:** la hipótesis se escribió, se probó en el motor y se
descartó/documentó. No se dejó la afirmación de la IA como conclusión.

Planes usados: `docs/planes/Q6_competencia_despues.txt`, `docs/planes/Q4_facturacion_clientes_antes.txt`, `docs/planes/Q4_facturacion_clientes_despues.txt`.