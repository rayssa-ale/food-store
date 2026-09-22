# spec: indice_producto_stock_reposicion

**Objetivo:** acelerar el reporte operativo "productos a reponer" (stock bajo).

**Consulta afectada (frecuente, corre varias veces al día en el local):**

```sql
SELECT p.id, p.nombre, p.precio, p.stock
FROM producto p
WHERE p.activo AND p.stock < 50
ORDER BY p.stock, p.id
LIMIT 100;
```

**Columnas candidatas:** `stock` (filtro de rango + primer término del
`ORDER BY`), `activo` (bool, baja selectividad).

**Justificación del tipo:** índice **parcial** `ON producto (stock)
WHERE stock < 50` — solo se indexan las ~12,4 k filas que interesan al
reporte (de 50 k), no las 37 k con stock suficiente. Muestra el criterio de
"condición de un índice parcial" de la teoría (menor espacio y menor costo de
mantenimiento que indexar toda la columna). El `ORDER BY stock` queda
presorted: el plan deja de ordenar 12,4 k filas para devolver las primeras
100.

**Criterio de aceptación:** el plan pasa de `Seq Scan` sobre los 50 k
productos (+ `Sort`) a un `Index Scan`/`Bitmap` con `Index Cond (stock < 50)`
y el tiempo baja de forma medible.

**Dato de entorno:** `food_store_tp5`, 50.006 productos activos, 12.443 con
stock < 50, stock en [0, 200].