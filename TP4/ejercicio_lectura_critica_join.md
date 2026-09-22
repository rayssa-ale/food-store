# Ejercicio de lectura crítica: plan con JOIN múltiple interpretado por IA (TP4, Parte 2)

**Materia:** Base de Datos II — UTN · **Proyecto:** Food Store · **Fecha:** 22/09/2026
**Plan analizado:** `docs/planes4/T3_top50_pedidos_antes.txt` (top 50 pedidos por importe, con cliente y líneas)

## Contexto

El plan de T3 combina tres algoritmos de join reales: un **Nested Loop** (con
`Memoize`), un **Merge Join** y un **Incremental Sort** para el agregado. Se le
pasó el texto del plan (sin otro contexto) a la IA para que lo explicara "nodo
por nodo", con foco en qué tabla es externa e interna en cada join. La consigna
exige contrastar: la IA tiende a leer el costo estimado de un nodo como tiempo
y a confundir el orden de las tablas.

## 3.1 … explicación generada por la IA (textual)

> "El plan primero ordena las 500.014 líneas de `detalle_pedido` por
> `pedido_id` con un Sort, y después un Merge Join mezcla esas líneas con la
> salida del Nested Loop. En el Nested Loop la tabla **externa es cliente** e
> **interna es pedido**, y el `Memoize` guarda en memoria los pedidos ya vistos
> para no releerlos. El costo estimado del Merge Join (51.376) equivale a unos
> 51 milisegundos de ese paso; el 30% del tiempo total (791 ms) es el
> Incremental Sort que ordena a los clientes. Como la consulta pide 50 pedidos,
> el plan solo procesa los mejores 50."

## 3.2 Contraste contra el plan real

| # | Afirmación de la IA | ¿Correcta? | Corrección · evidencia del plan real |
|---|---|---|---|
| 1 | "Se ordena `detalle_pedido` con un Sort antes del Merge Join" | ✗ | No hay ningún nodo `Sort` sobre detalle: el Merge Join lee las líneas desde el **índice** `Index Scan using uq_detalle_pedido_producto` (ya ordenado por `pedido_id`), `cost=0.42..24870.51`. Lo único que ordena es el `Incremental Sort` con `Sort Key: pe.id, c.nombre, c.apellido` (por cliente), no las líneas. |
| 2 | "En el Nested Loop la tabla externa es `cliente` y la interna es `pedido`" | ✗ | Es al revés: la externa es `pedido` (`Index Scan using pedido_pkey ... Filter estado <> 'CANCELADO'`, 166.857 filas) y la interna es `cliente` (`cliente_pkey`, vía Memoize). El plan lo muestra por orden de anidación: `-> Nested Loop` / `-> pedido` / `-> Memoize → cliente`. |
| 3 | "El `Memoize` guarda en memoria los pedidos para no releerlos" | ✗ | Memoize cachea el **resultado del lookup a `cliente` por `cliente_id`**: `Cache Key: pe.cliente_id`, con `Hits: 146860, Misses: 19997` (19997 clientes distintos resueltos y reutilizados). No guarda pedidos. |
| 4 | "El costo estimado del Merge Join (51.376) equivale a ~51 milisegundos" | ✗ | El `cost` de EXPLAIN es adimensional (ponderación de I/O + CPU del optimizador), no tiempo. El tiempo real del Merge Join se lee de `actual time`: 0.239..399.562 ms. |
| 5 | "El 30% del tiempo total es el Incremental Sort que ordena clientes" | Parcial | El Incremental Sort (`actual time=0.385..511.018 ms`) sí es un nodo caro, pero también lo es el Merge Join (~399 ms) y el GroupAggregate (~350 ms). Ninguno es "el 30%"; la afirmación de reparto es inventada, no viene del plan. |
| 6 | "Como pide 50 pedidos, el plan procesa solo los mejores 50" | ✗ | El plan recorre **166.857 pedidos** y **500.014 líneas** (y agrega por `Group Key: pe.id, c.nombre, c.apellido`) **antes** del `Limit 50`. El Limit (`top-N heapsort`) es el último nodo. |

**Conclusión:** 5 de 6 afirmaciones resultaron falsas o parciales. Las dos
imprecisiones más graves son la **inversión de tabla externa/interna** del
Nested Loop (afecta la lectura del plan para proponer optimizaciones) y la
**confusión costo estimado vs tiempo real** (afecta la interpretación de
cualquier propuesta). Regla para el informe y la defensa: citar siempre el nodo
textual (`-> Nested Loop`, `Hits/Misses`, `actual time`) y nunca la
interpretación libre de la IA.

## 3.3 Qué significó esto para las propuestas

Esta lectura crítica evitó aceptar la propuesta "colocar un índice en
`cliente(apellido)` porque el Incremental Sort es el 30%": el nodo Interno real
del Incremental Sort era la **clave de agrupación `(pe.id, c.nombre,
c.apellido)` de salida del Merge Join**, y el verdadero cuello era el volumen
que atraviesa el join (166k × 500k), no la resolución de clientes. Por eso la
reescritura de T3 (agregar por `pedido_id` primero y adjuntar el cliente solo a
los 50 elegidos) atacó el nodo correcto.