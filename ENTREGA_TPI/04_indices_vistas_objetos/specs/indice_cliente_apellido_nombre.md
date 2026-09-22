# spec: indice_cliente_apellido_nombre

**Objetivo:** acelerar la búsqueda de clientes por apellido (panel de
atención al cliente / caja), con orden alfabético.

**Consulta afectada (frecuente, corre decenas de veces al día):**

```sql
SELECT c.nombre, c.apellido, c.email
FROM cliente c
WHERE c.apellido LIKE 'Apellido15%'
ORDER BY c.apellido, c.nombre
LIMIT 20;
```

**Columnas candidatas:** `apellido` (filtro de prefijo + primer término del
`ORDER BY`), `nombre` (segundo término del `ORDER BY`).

**Justificación del tipo:** índice compuesto
`ON cliente (apellido text_pattern_ops, nombre text_pattern_ops)`. La clase
de operador `text_pattern_ops` es la que permite usar B-tree para `LIKE
'prefijo%'` en una base cuyo collation por defecto no es `C`; sin ella el
planificador no puede explotar el rango del prefijo. El índice compuesto
también deja el `ORDER BY apellido, nombre` presorted (sin `Sort`).

**Criterio de aceptación:** el plan pasa de `Seq Scan` (20 k filas) + `Sort`
a un `Index Scan` por rango de prefijo con `Index Cond` sobre `apellido`,
presorted (paginación sin `Sort`).

**Dato de entorno:** `food_store_tp5`, 20.003 clientes; la carga genera
apellidos "ApellidoNNNNN", el prefijo "Apellido15" devuelve ~1.111 filas
(5.5 %).

**Nota de adaptación:** la clase de operador se documenta en el informe
porque es el aspecto "tipo de índice" de la teoría (B-tree + opclass), no un
detalle cosmético.