# spec: materializada mv_facturacion_categoria_mes_pago

**Objetivo:** reporte agregado costoso del sistema: facturación por
**categoría, mes y forma de pago** (conteo y línea de referencia: la Semana 4
ya materializó el agregado por categoría/mes; este es el mismo reporte
enriquecido con la dimensión **forma de pago**, con un 5.º objetivo extra: el
índice único para `REFRESH CONCURRENTLY`).

**Consulta original (a comparar):**

```sql
SELECT c.nombre AS categoria,
       date_trunc('month', pe.fecha) AS mes,
       pe.forma_pago,
       SUM(d.cantidad * d.precio_unitario) AS facturado,
       COUNT(*)                            AS lineas
FROM detalle_pedido d
JOIN pedido   pe ON pe.id = d.pedido_id
JOIN producto p  ON p.id = d.producto_id
JOIN categoria c ON c.id = p.categoria_id
WHERE pe.estado = 'ENTREGADO'
GROUP BY c.nombre, date_trunc('month', pe.fecha), pe.forma_pago;
```

Cada ejecución re-escanea las 500 k líneas y los 200 k pedidos por una
pestaña de gerencia que muestra ~100 filas.

**Vista materializada a generar:** mismo `SELECT` con `WITH DATA`, más un
índice ÚNICO `(categoria, mes, forma_pago)` que da unicidad (el GROUP BY
produce un único valor por tupla) y habilita `REFRESH MATERIALIZED VIEW ...
CONCURRENTLY`.

**Criterios de aceptación:**
1. La lectura contra la MV es órdenes de magnitud más rápida que la consulta
   original (mismo EXPLAIN ANALYZE, en caliente).
2. El índice único permite planificar el `REFRESH CONCURRENTLY` (no falla al
   crearlo).
3. Resultados equivalentes: MV vs consulta original, `EXCEPT` 0/0.
4. Queda documentada la frecuencia de refresco sugerida y qué implica para el
   usuario que la MV quede "vieja" entre refrescos.