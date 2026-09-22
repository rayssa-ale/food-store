# Registro del desafío de la competencia (TP4, Parte 4)

**Equipo G · Proyecto:** Food Store · **Fecha:** 22/09/2026
**Herramienta de IA:** OpenCode (CLI, modelo *big-pickle)
**Foco curricular:** joins + agregación + funciones de ventana en una
consulta analítica real sobre la copia `food_store_tp3`.

## Consulta fija de la competencia

Reporte con **3 tablas** (pedido, detalle_pedido, cliente), **2 joins**,
**agregación** (`SUM`, `COUNT`, filtro `HAVING`) y **función de ventana**
(running total) — la métrica de "clientes frecuentes", definida como
clientes con **5 o más meses** con ventas ENTREGADO:

```sql
WITH compras AS (
    SELECT pe.cliente_id, date_trunc('month', pe.fecha) AS mes,
           SUM(d.cantidad * d.precio_unitario) AS facturado
    FROM pedido pe
    JOIN detalle_pedido d ON d.pedido_id = pe.id
    WHERE pe.estado = 'ENTREGADO'
    GROUP BY pe.cliente_id, date_trunc('month', pe.fecha)
)
SELECT c.id, c.nombre || ' ' || c.apellido AS nombre,
       to_char(m.mes, 'YYYY-MM') AS mes,
       m.facturado,
       SUM(m.facturado) OVER (PARTITION BY c.id ORDER BY m.mes) AS acumulado
FROM compras m
JOIN cliente c ON c.id = m.cliente_id
WHERE c.id IN (
    SELECT cliente_id FROM compras
    GROUP BY cliente_id HAVING COUNT(*) >= 5
)
ORDER BY c.id, m.mes;
```

Resultado: 46.322 filas (8.017 clientes frecuentes).

## Diagnóstico del plan real (EXPLAIN ANALYZE, en caliente)

El plan "antes" no está limitado por un join: los dos `Hash Join` terminan
en ~220 ms. El costo dominante es que la **CTE `compras` se materializa a
disco y se lee DOS veces** (`Storage: Disk  Maximum Storage: 4096kB`,
`temp read=1634 written=2372`), porque el `HashAggregate` de 82.532
(cliente, mes) derrama en 5 batches (`Batches: 5  Disk Usage: 7880kB`), y
además hay un `Sort` de 4,6 MB (`Sort Method: external merge  Disk: 2616kB`)
antes del `WindowAgg`. Todo eso se paga por cada corrida del reporte.

## Estrategia aplicada (materialización analítica)

1. **Propuesta de IA aceptada (OPT-T5):** materializar el agregado
   `(cliente, mes, facturado)` en una vista materializada, porque es un
   dashboard que se consulta repetidamente y solo cubre pedidos ENTREGADO
   (registros cerrados). La consulta queda **semánticamente idéntica**:
   la MV es exactamente la CTE del original; el filtro de frecuentes
   (`>= 5 meses`) y el running total se re-aplican sobre la MV.
2. **Índice de soporte** `ix_mv_fact_cliente_mes (cliente_id, mes)` para la
   partición del `WindowAgg` y el join con cliente, más `ANALYZE`.

```sql
CREATE MATERIALIZED VIEW mv_fact_cliente_mes AS
SELECT pe.cliente_id, date_trunc('month', pe.fecha) AS mes,
       SUM(d.cantidad * d.precio_unitario)          AS facturado
FROM pedido pe
JOIN detalle_pedido d ON d.pedido_id = pe.id
WHERE pe.estado = 'ENTREGADO'
GROUP BY pe.cliente_id, date_trunc('month', pe.fecha)
WITH DATA;

CREATE INDEX ix_mv_fact_cliente_mes ON mv_fact_cliente_mes (cliente_id, mes);
ANALYZE mv_fact_cliente_mes;
```

## Medición final (EXPLAIN (ANALYZE, BUFFERS), en caliente)

| Fase | Nodos dominantes | Execution Time real |
|---|---|---|
| **Antes** | CTE materializada a disco + leída 2× (HashAggregate con Batches: 5, Disk 7880kB) + Sort external merge 2616kB + WindowAgg | **825.829 ms** |
| **Después** | 2× Seq Scan sobre MV (82.532 filas) + Hash Joins en memoria + Sort de 2616kB + WindowAgg | **236.047 ms** |

**Mejora: 825.829 / 236.047 = ×3.5**, con buffers compartidos 29.971 → 1.422
y sin escritura de batches a disco en el agregado.

## Detalle del plan ganador

```
WindowAgg  (cost=6416.01..7123.01 rows=25709)
  Window: w1 AS (PARTITION BY c.id ORDER BY m.mes)
  ->  Sort  Sort Key: c.id, m.mes
  ->  Hash Join  (m.cliente_id = c.id)      — Seq Scan cliente (20.003)
        ->  Hash Join  (m.cliente_id = mv.cliente_id)
              ->  Seq Scan on mv_fact_cliente_mes (82.532 filas)
              ->  HashAggregate  (Group Key: cliente_id, Filter: count(*) >= 5)
Execution Time: 236.047 ms
```

La MV elimina el doble materializado a disco y el re-scan de 500.014 líneas;
el plan completo quedó en `docs/planes4/T5_fact_mensual_acum_antes.txt` y
`docs/planes4/T5_fact_mensual_acum_despues.txt`.

## Transparencia: qué se probó y se descartó

- **OPT-T5-A (intento A, RECHAZADO):** mover `HAVING COUNT(*) >= 5` dentro
  de la CTE (agrupando por mes) *parecía* equivalente pero **cambió la
  semántica**: "frecuente" pasó de "≥5 meses" a "≥5 líneas en un mes"
  (46.322 → 10.211 filas). Fue detectado comparando conteos y se descartó.
- **Ajuste de `work_mem`:** probado para el Sort en T2 (antes 3.096 ms →
  965 ms con 256 MB de sesión); para T5 no era la palanca correcta: el
  cuello es la materialización doble de la CTE y 8.2 MB de batches, y
  `work_mem` de sesión no perdura en producción, mientras que la MV sí.
- **Verificación formal:** la equivalencia original ↔ MV se confirmó con
  `EXCEPT` 0/0 en ambas direcciones (Parte 3, especificaciones de T5 en
  `sql/equivalencias_tp4.sql` y `docs/informe_equivalencias_tp4.md`).

Scripts: `sql/optimizaciones_tp4.sql` (DDL) y `sql/queries_tp4_opt.sql`
(consulta "después", SQL idéntico en semántica al original).