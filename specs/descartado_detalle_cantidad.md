# spec: DESCARTADO indice_detalle_cantidad (sobreindexación)

**Propuesta de la IA (probe descartada):**

```sql
CREATE INDEX idx_detalle_cantidad ON detalle_pedido (cantidad);
```

**Premisa:** acelerar "top 10 productos más vendidos por unidades" (query Q3
de la Semana 3), pensando que "un índice en `cantidad` acelera el SUM".

**Veredicto — DESCARTADO:**

1. Q3 es una **agregación de tabla completa**: debe sumar las 500.014 líneas
   como estén ordenadas. Un índice B-tree en `cantidad` no evita leer el 100 %
   de la tabla; el plan sigue siendo `Seq Scan on detalle_pedido` +
   `GroupAggregate` y el índice jamás aparece en él (se comprueba con
   `EXPLAIN`).
2. Es el caso clásico de la teoría: "un índice siempre ayuda" es falso.
   Indexar una columna sobre la que se agrega, sin filtro, solo aumenta el
   costo de escritura de la tabla más voluminosa del sistema (INSERT de
   líneas, que además se mide en la Parte A.5).
3. De haberse creado, cada INSERT de línea pagaría otro índice de ~16 MB por
   cero beneficio de lectura.

**Decisión:** no se crea. Se verifica con `EXPLAIN` de Q3 antes/después (el
plan no cambia) y el dato queda en el informe como justificación.

**Nota:** si algún día el reporte filtra por fecha ("vendidos desde el mes
pasado"), la palanca sería un índice por `(fecha)` en `pedido` + join, no un
índice en `cantidad`.