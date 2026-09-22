# spec: indice_pedido_fecha_estado

**Objetivo:** acelerar el reporte de gerencia "pedidos del mes".

**Consulta afectada (frecuente, corre 1×/día o bajo demanda):**

```sql
SELECT pe.id, pe.fecha, pe.estado, pe.forma_pago, pe.cliente_id
FROM pedido pe
WHERE pe.fecha >= '2026-01-01' AND pe.fecha < '2026-02-01'
ORDER BY pe.fecha, pe.id;
```

**Plan actual (verificado con EXPLAIN ANALYZE):** `Seq Scan on pedido`
(200 k filas) + filtro de fecha + `Sort` por `(fecha, id)`. El índice
existente `ix_pedido_estado` no tiene a `fecha` como columna líder y por eso
no participa: no hay ningún índice con prefijo `fecha`.

**Columnas candidatas:** `fecha` (alta selectividad — un mes ≈ 8 % de 200 k
pedidos), `estado` (baja selectividad — mitad ENTREGADO); el `ORDER BY fecha`
también participa.

**Justificación del tipo:** índice compuesto `(fecha, estado)`. `fecha` como
columna líder convierte el rango de mes en el punto de entrada del árbol y
deja el `ORDER BY fecha` presorted (elimina el `Sort`). `estado` como columna
secundaria sirve a la variante `estado = 'ENTREGADO'` del mismo reporte
(dashboard), donde hoy el plan re-lee los 100 k ENTREGADO para quedarse con
~8,5 k del mes.

**Criterio de aceptación (lo que resuelve OpenCode):** el plan pasa de
`Seq Scan on pedido` (200 k filas leídas + `Sort`) a un `Index Scan` sobre el
rango del mes (~16,8 k filas, presorted, sin `Sort`) y el tiempo baja al
menos un orden de magnitud.

**Dato de entorno:** servido por la copia `food_store_tp5` (200.003 pedidos,
fecha entre 2025-09 y 2026-09, ~16,8 k pedidos/mes).