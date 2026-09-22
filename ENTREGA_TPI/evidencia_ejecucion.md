# Evidencia de ejecución — Food Store · TPI (entrega parcial)

Capturas y resultados reales obtenidos del motor para verificar el
funcionamiento. **Corrida:** 22/09/2026 · PostgreSQL 18 · database `food_store_tp5`
(copia de trabajo). Toda la evidencia es reproducible con los scripts que se
citan; las transacciones de demostración terminan en `ROLLBACK` y no alteran datos.

- Reglas R8–R10 y procedimientos: `sql/evidencia_restricciones_TPI.sql` y
  `sql/prueba_procedimientos_TPI.sql`.
- Vistas y MV: `sql/verificacion_views.sql`, `sql/verificacion_materializada.sql`.
- Planes EXPLAIN antes/después: `docs/planes4/`, `docs/planes5/`, `docs/planes/`.

---

## 1. DDL y carga de datos (objetivos 1–4, 7, 9)

Conteos de la copia masiva sobre la que se midió (212.008 pedidos, 512.029 líneas):

```
 categorias | productos | clientes | pedidos | lineas
------------+-----------+----------+---------+--------
          3 |     50006 |    20003 |  212008 | 512029
```

Catálogo: funciones y procedimientos PL/pgSQL, triggers y vistas existentes:

```
             objeto             |   tipo    | retorno
--------------------------------+-----------+---------
 calcular_total_pedido          | FUNCTION  | numeric
 check_transicion_estado_pedido | FUNCTION  | trigger
 proteger_precio_unitario       | FUNCTION  | trigger
 registrar_reposicion           | PROCEDURE |
 resumen_pedido_jsonb           | FUNCTION  | jsonb
 verificar_y_descontar_stock    | FUNCTION  | trigger

            tgname
------------------------------
 trg_detalle_auditoria_carga      (statement, transición)
 trg_detalle_precio_congelado     (R10)
 trg_detalle_stock                (R9)
 trg_pedido_estado_transicion     (R8)

          table_name
------------------------------
 v_cliente_contacto
 v_reporte_detalle_pedido
 v_reporte_pedidos_cliente
 v_reporte_productos_vigentes
```

## 2. Reglas de negocio R8–R10 (objetivo 7)

Salida de `sql/evidencia_restricciones_TPI.sql` (una transacción, ROLLBACK final;
cada caso inválido en su SAVEPOINT):

```
=== R8 (valida): PENDIENTE -> EN_PREPARACION -> ENTREGADO ===
   id   |     estado
--------+----------------
 212011 | EN_PREPARACION
   id   |  estado
--------+-----------
 212011 | ENTREGADO

=== R8 (invalida): ENTREGADO -> CANCELADO (estado terminal) ===
^ esperado: ERROR R8 pedido en estado terminal    [SAVEPOINT/ROLLBACK]

=== R9 (valida): la venta descuenta stock atomicamente ===
   id   | pedido_id | producto_id | cantidad | precio_unitario
--------+-----------+-------------+----------+-----------------
 512029 |    212011 |           1 |        2 |         1200.00
  id |   nombre   | stock
-----+------------+-------
   1 | Muzzarella |    68

=== R9 (invalida): stock insuficiente rechazado (producto 2) ===
^ esperado: ERROR R9 stock insuficiente            [SAVEPOINT/ROLLBACK]

=== R10 (invalida): precio_unitario de la linea congelado ===
^ esperado: ERROR R10 precio congelado             [SAVEPOINT/ROLLBACK]

 lineas_demo_que_quedan
------------------------
                      0     <-- sin huella tras ROLLBACK
```

Mensajes emitidos por el motor ante cada caso inválido:

```
ERROR:  R8: pedido 212011 en estado terminal (ENTREGADO), no puede cambiar a CANCELADO
CONTEXTO: función PL/pgSQL check_transicion_estado_pedido() en la línea 13 en RAISE

ERROR:  R9: stock insuficiente (o producto inactivo) para producto 2, se piden 999999 unidades
CONTEXTO: función PL/pgSQL verificar_y_descontar_stock() en la línea 10 en RAISE

ERROR:  R10: el precio unitario de la línea 1 está congelado (R4)
CONTEXTO: función PL/pgSQL proteger_precio_unitario() en la línea 4 en RAISE
```

## 3. Transacciones, aislamiento y concurrencia (objetivo 8)

Escenarios reproducidos en `docs/informe_concurrencia.md` con dos sesiones `psql`
(los tiempos son de corrida real):

| Escenario | Aislamiento | Resultado verificado |
|---|---|---|
| Lectura no repetible | READ COMMITTED | precio cambió 1200 → 1300 entre leer y releer |
| Lectura no repetible / fantasma | REPEATABLE READ | instantánea fija: COUNT estable, sin repetición |
| Espera por fila bloqueada | READ COMMITTED + `FOR UPDATE` | UPDATE de B desbloqueó recién 4,51 s después del COMMIT de A |
| Escritura cruzada en conflicto | `FOR UPDATE` | B abortó con `40P01` (el motor prefiere abortar) |

Atomicidad también demostrada en §6: el `ROLLBACK` revierte la fila de
auditoría (`filas_auditoria_tras_rollback = filas_auditoria_antes`).

## 4. Optimización de consultas (objetivo 5 · Unidad 2)

Plan `EXPLAIN (ANALYZE)` real de T1 (facturación por categoría/mes) antes y
después de la vista materializada:

##### T1 ANTES — Seq Scan 250.070 filas · 540,8 ms (plan completo en `docs/planes4/T1_fact_cat_mes_antes.txt`)

```
Sort  (cost=156222.89..156851.87 rows=251591 width=258) (actual time=495.139..529.482 rows=39.00 loops=1)
  Sort Key: (to_char((date_trunc('month'::text, pe.fecha)), 'YYYY-MM'::text)), c.nombre
  Sort Method: quicksort  Memory: 27kB
  Buffers: shared hit=8458, temp read=1318 written=1321
  ->  GroupAggregate  (cost=33631.67..71739.27 rows=251591 width=258) (actual time=364.389..529.320 rows=39.00 loops=1)
        Group Key: c.nombre, (date_trunc('month'::text, pe.fecha))
        Buffers: shared hit=8458, temp read=1318 written=1321
        ->  Gather Merge  (cost=33631.67..62933.59 rows=251591 width=203) (actual time=363.354..457.971 rows=250070.00 loops=1)
              Workers Planned: 2
              Workers Launched: 2
              Buffers: shared hit=8458, temp read=1318 written=1321
              ->  Sort  (cost=32631.64..32893.72 rows=104830 width=203) (actual time=316.382..328.052 rows=83356.67 loops=3)
                    Sort Method: external merge  Disk: 3472kB
                    ->  Hash Join  (cost=5878.18..13498.53 rows=104830 width=203) (actual time=58.589..231.458 rows=83356.67 loops=3)
                          Hash Cond: (p.categoria_id = c.id)
                          ->  Hash Join  (cost=5865.71..12938.20 rows=104830 width=25) (actual time=57.843..183.968 rows=83356.67 loops=3)
                                Hash Cond: (d.producto_id = p.id)
                                ->  Parallel Hash Join  (cost=3877.57..10674.87 rows=104830 width=25) (actual time=28.522..110.680 rows=83356.67 loops=3)
                                      Hash Cond: (d.pedido_id = pe.id)
                                      ->  Parallel Seq Scan on detalle_pedido d  (cost=0.00..6250.39 rows=208339 width=25) (actual time=0.025..18.015 rows=166671.33 loops=3)
                                      ->  Parallel Hash  (cost=3137.61..3137.61 rows=59197 width=16) (actual time=28.234..28.235 rows=33349.67 loops=3)
                                            ->  Parallel Seq Scan on pedido pe  (cost=0.00..3137.61 rows=59197 width=16) (actual time=0.017..21.873 rows=50024.50 loops=2)
                                                  Filter: (estado = 'ENTREGADO'::estado_pedido)
                                                  Rows Removed by Filter: 49977
Planning Time: 8.590 ms
Execution Time: 540.832 ms
```


##### T1 DESPUÉS — vista materializada · 0,29 ms · ×1.846 (plan completo en `docs/planes4/T1_fact_cat_mes_despues.txt`)

```
Sort  (cost=2.52..2.62 rows=39 width=54) (actual time=0.253..0.253 rows=39.00 loops=1)
  Sort Key: (to_char(mes, 'YYYY-MM'::text)), categoria
  Sort Method: quicksort  Memory: 26kB
  Buffers: shared hit=4
  ->  Seq Scan on mv_ventas_categoria_mes  (cost=0.00..1.49 rows=39 width=54) (actual time=0.139..0.155 rows=39.00 loops=1)
        Buffers: shared hit=1
Planning Time: 2.004 ms
Execution Time: 0.293 ms
```


Resumen de las consultas optimizadas (detalle en `informe_tecnico_TPI.md`):

| Consulta | Técnica | Antes | Después | Ganancia |
|---|---|---|---|---|
| T1 facturación categoría/mes | MV | 540,8 ms | 0,29 ms | **×1.846** |
| T2 top 3 por categoría | `work_mem` | 125 s | 29 s | **×4,3** |
| T3 top 50 pedidos | reescritura | 78,1 ms | 47,9 ms | ×1,63 |
| T5 acumulado mensual | MV | 6.593 ms | 1.887 ms | **×3,5** |
| Q6 (TP3, competencia) | índice cubriente | 14,24 ms | 0,34 ms | **×42** |

## 5. Vistas (objetivo 6)

Salida de `sql/verificacion_views.sql`: equivalencia con la consulta manual
(`EXCEPT` → 0 filas) sobre las 4 vistas, y comprobación de que la vista de
seguridad **no expone** `telefono`:

```
 chequeo  |   a   |   b
----------+-------+-------
 v1_filas | 50006 | 50006        v1_menos_manual = 0 · v1_manual_menos = 0
 v2_filas | 212006 | 212006      v2_menos_manual = 0 · v2_manual_menos = 0
 v3_filas | 512023 | 512023      v3_menos_manual = 0 · v3_manual_menos = 0
 v4_filas | 20003 | 20003        v4_menos_manual = 0 · v4_manual_menos = 0
        chequeo        | columnas_telefono
-----------------------+-------------------
 v4_no_expone_telefono |                 0
```

## 6. Objetos programables (objetivo 6 · nota PostgreSQL 16+)

Salida de `sql/prueba_procedimientos_TPI.sql`:

```
=== 1) Procedimiento CALL: registrar_reposicion (productos 1-3) ===
  id |    nombre     | stock
----+---------------+-------
  1 | Muzzarella    |    90
  2 | Napolitana    |    88
  3 | Jamón y Queso |    85

=== 2) Reposición inválida: cantidad <= 0 y producto descartado ===
   ERROR: la cantidad de reposición debe ser > 0 (se recibió 0)
   ERROR: producto 999999 inexistente o dado de baja, no se repone

=== 3) Tabla de transición: 1 fila de auditoría por SENTENCIA (3 líneas) ===
 n_lineas | monto_total |          inserted_at
----------+-------------+-------------------------------
        3 |     8100.00 | 2026-09-22 17:23:53.577821-03

=== 4) Funciones de negocio ===
 total_pedido_demo  | 8100.00
 total_proviene_de_lineas | t     (total = SUM de las líneas)
 nombre_cliente | Dana  ·  primer_producto_jsonb | Jamón y Queso

=== JSONB completo (pretty) ===
{
    "fecha": "2026-09-22T17:23:53.577821-03:00",
    "total": 8100.00,
    "estado": "PENDIENTE",
    "lineas": [ { "cantidad": 3, "producto": "Jamón y Queso", "subtotal": 4200.00, ... },
                { ... "Muzzarella" ... }, { ... "Napolitana" ... } ],
    "pedido": 212012,
    "cliente": { "id": 1, "nombre": "Dana", "apellido": "Da Luz" },
    "forma_pago": "EFECTIVO"
}

=== 5) La fila de auditoría persiste tras COMMIT ===
 id | n_lineas | monto_total | inserted_at
----+----------+-------------+-------------------------------
  7 |        3 |     8100.00 | 2026-09-22 17:23:53.577821-03

=== 6) Atomicidad: ROLLBACK revierte también la auditoría ===
 filas_auditoria_antes | 3   ·   filas_auditoria_en_tx | 4   ·   filas_auditoria_tras_rollback | 3
```

## 7. Vista materializada (Unidad 3)

Equivalencia original ↔ MV (`0/0`) y `REFRESH CONCURRENTLY`:

```
 mv_menos_original  | 0
 original_menos_mv  | 0
 REFRESH MATERIALIZED VIEW        (concurrente, OK)
```

Plan del MISMO cálculo antes (905,8 ms) y con la MV (0,022 ms — **×41.000**):

##### C1 ORIGINAL — GroupAggregate sobre 250.070 líneas · 905,8 ms

```
GroupAggregate  (cost=32473.41..68733.49 rows=243411 width=230) (actual time=574.436..888.866 rows=117.00 loops=1)
  Group Key: c.nombre, (date_trunc('month'::text, pe.fecha)), pe.forma_pago
  Buffers: shared hit=6279, temp read=1195 written=1198
  ->  Gather Merge  (cost=32473.41..60822.63 rows=243411 width=199) (actual time=573.769..749.385 rows=250070.00 loops=1)
        Workers Planned: 2
        Workers Launched: 2
        ->  Sort  (cost=31473.39..31726.94 rows=101421 width=199) (actual time=499.775..529.144 rows=83356.67 loops=3)
              Sort Method: external merge  Disk: 3296kB
              ->  Hash Join  (cost=5574.52..13331.23 rows=101421 width=199) (actual time=53.820..319.753 rows=83356.67 loops=3)
                    Hash Cond: (p.categoria_id = c.id)
                    ->  Parallel Hash Join  (cost=5562.05..12788.72 rows=101421 width=29) (actual time=52.963..238.024 rows=83356.67 loops=3)
                          Hash Cond: (d.producto_id = p.id)
                          ->  Parallel Hash Join  (cost=4066.92..11027.34 rows=101421 width=29) (actual time=41.026..164.671 rows=83356.67 loops=3)
                                Hash Cond: (d.pedido_id = pe.id)
                                ->  Parallel Seq Scan on detalle_pedido d  (cost=0.00..6400.39 rows=213339 width=25) (actual time=0.046..26.498 rows=170671.33 loops=3)
                                ->  Parallel Hash  (cost=3325.85..3325.85 rows=59286 width=20) (actual time=39.828..39.829 rows=33349.67 loops=3)
                                      ->  Parallel Seq Scan on pedido pe  (cost=0.00..3325.85 rows=59286 width=20) (actual time=0.028..23.188 rows=33349.67 loops=3)
                                            Filter: (estado = 'ENTREGADO'::estado_pedido)
                                            Rows Removed by Filter: 37318
                          ->  Parallel Hash  (cost=1234.68..1234.68 rows=20836 width=16) (actual time=11.702..11.703 rows=16668.67 loops=3)
                                ->  Parallel Index Only Scan using ix_producto_cat_cover on producto p  (cost=0.29..1234.68 rows=20836 width=16) (actual time=0.037..13.277 rows=50006.00 loops=1)
Planning Time: 15.148 ms
Execution Time: 905.820 ms
```


##### C1 CON MV — Seq Scan sobre 117 filas · 0,022 ms

```
Seq Scan on mv_facturacion_categoria_mes_pago  (cost=0.00..2.17 rows=117 width=34) (actual time=0.007..0.012 rows=117.00 loops=1)
  Buffers: shared hit=1
Planning Time: 0.033 ms
Execution Time: 0.022 ms
```


## 8. Índices con justificación de plan (Unidad 3 · objetivo 9)

A2 (reposición de stock) usa índice **parcial** `WHERE stock < 50`. Plan real
antes (Seq Scan sobre 50.006 productos) y después (Index Scan, 10,4 → 0,34 ms —
**×30,4**):

##### A2 ANTES — Seq Scan · 10,35 ms

```
Limit  (cost=1954.27..1954.52 rows=100 width=33) (actual time=10.320..10.328 rows=100.00 loops=1)
  Buffers: shared hit=863
  ->  Sort  (cost=1954.27..1984.77 rows=12198 width=33) (actual time=10.317..10.320 rows=100.00 loops=1)
        Sort Key: stock, id
        Sort Method: top-N heapsort  Memory: 36kB
        Buffers: shared hit=863
        ->  Seq Scan on producto p  (cost=0.00..1488.08 rows=12198 width=33) (actual time=0.015..7.584 rows=12443.00 loops=1)
              Filter: (activo AND (stock < 50))
              Rows Removed by Filter: 37563
              Buffers: shared hit=863
Planning Time: 0.259 ms
Execution Time: 10.351 ms
```


##### A2 DESPUÉS — Index Scan parcial · 0,34 ms

```
Limit  (cost=20.48..54.32 rows=100 width=33) (actual time=0.308..0.319 rows=100.00 loops=1)
  Buffers: shared hit=201
  ->  Incremental Sort  (cost=20.48..4218.30 rows=12405 width=33) (actual time=0.307..0.311 rows=100.00 loops=1)
        Sort Key: stock, id
        Presorted Key: stock
        Sort Method: quicksort  Average Memory: 29kB  Peak Memory: 29kB
        Buffers: shared hit=201
        ->  Index Scan using ix_producto_stock_reposicion on producto p  (cost=0.29..3690.31 rows=12405 width=33) (actual time=0.016..0.225 rows=226.00 loops=1)
              Filter: activo
              Index Searches: 1
              Buffers: shared hit=201
Planning Time: 0.157 ms
Execution Time: 0.342 ms
```


Índices A1/A3 y costo de escritura (`informe_mediciones.md`):

| Ítem | Antes | Después | Diferencia |
|---|---|---|---|
| A1 pedidos del mes `(fecha, estado)` | 18,8 ms | 11,5 ms | ×1,6 |
| A3 cliente por apellido (opclass) | 2,75 ms | 1,40 ms | ×2,0 |
| Escritura: pedido | 234,5 ms | 237,8 ms | +1,4 % |
| Escritura: detalle_pedido | 416,8 ms | 304,7 ms | ruido (n/s) |

> Las corridas con planes completos de todas las consultas (T1–T5, A1–A3, D1-C1)
> están archivadas en `docs/planes4/`, `docs/planes5/` y `docs/planes/`.