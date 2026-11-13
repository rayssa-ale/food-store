# tasks.md — Unidad 4 (TP6)

**Estado:** cerrada. Commits `b2bde0d` (Parte 1) y `aa59180` (Parte 2).
**Base de trabajo:** `food_store_tp6` (copia de `food_store_tp5`).

## 1. Preparación

- [x] Verificar el protocolo de copia: respaldo previo y `createdb -T` sobre una
      copia, nunca sobre `foodstore`.
- [x] Sembrar el día corriente con `TP6/carga_dia_actual.sql` para que el
      `EXPLAIN ANALYZE` no mida un conjunto vacío.
- [x] Confirmar que el esquema real no tiene `eliminado` ni `subtotal`
      (la baja es el ENUM `estado_pedido`; el subtotal es
      `cantidad * precio_unitario`).

## 2. Parte 1 — FNBC

- [x] Declarar `R` y `F+` con su lectura de negocio (§(a) del script).
- [x] Calcular clausuras y enumerar K1 y K2 (§(b)).
- [x] Clasificar atributos primos y no primos (§(b)).
- [x] Dictaminar FNBC vs. 3FN (§(c)).
- [x] Crear `deposito`, `lote` y `usuario` mínimos, sin `deposito_id` en
      `usuario`.
- [x] Crear `control_lote_almacen` con PK `(lote_id, deposito_id)` y datos de
      prueba.
- [x] Demostrar anomalía de inserción en `SAVEPOINT` + `ROLLBACK TO`.
- [x] Demostrar anomalía de actualización en `SAVEPOINT` + `ROLLBACK TO`.
- [x] Demostrar anomalía de borrado en `SAVEPOINT` + `ROLLBACK TO`.
- [x] Crear `responsable_deposito` y `control_lote`.
- [x] Migrar los datos y verificar que FD2 se cumpla en el origen (si un
      responsable aparece en dos depósitos, el script debe fallar, no resolver
      con `DISTINCT`).
- [x] Crear la vista `control_lote_almacen_compat`.
- [x] Probar la reunión con `EXCEPT` bidireccional (0/0).
- [ ] **Pendiente (F-U4-4):** la descomposición entregada
      `(Resp, Dep) + (Lote, Dep)` es con pérdida en general; `Dep` no es
      superclave de ninguna. El 0/0 se explica por la instancia (un responsable
      por depósito). Corregir a `(Resp, Dep) + (Lote, Resp)` y agregar el
      contraejemplo con dos responsables en el mismo depósito.
- [x] Refutar la duplicación por `deposito_id` repetido en `control_lote`.

## 3. Parte 2 — Desnormalización

- [x] Medir el plan normalizado con `EXPLAIN (ANALYZE, BUFFERS, SETTINGS)`.
- [x] Corregir el predicado de fecha a rango semiabierto
      (`>= CURRENT_DATE AND < CURRENT_DATE + INTERVAL '1 day'`): con
      `fecha = CURRENT_DATE` el plan mide 0 filas sobre `TIMESTAMPTZ`.
- [x] Crear `fact_venta_categoria_dia` con PK natural y `NUMERIC(14,2)`.
- [x] Crear `ajustar_fact_venta()` y `recalcular_fact_venta_dia()`.
- [x] Crear los tres disparadores del camino caliente sobre `detalle_pedido`.
- [x] Crear los disparadores de camino frío sobre `pedido`, `producto` y
      `categoria`.
- [x] Ejecutar el backfill con la misma agregación del auditor.
- [x] Verificar la equivalencia antes/después con `EXCEPT` bidireccional.
- [x] Medir el plan del cubo (`3 filas`, `6 buffers`, `0,118 ms`).
- [x] Medir el costo de escritura del camino caliente.
- [x] Documentar los dos desvíos del enunciado en el script y en el informe
      (`eliminado`/`subtotal` inexistentes; fecha como rango).

## 4. Reversión

Runbook ejecutable (sobre la copia):

```powershell
$psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'

# 1. Estado previo de la fuente de verdad
& $psql -d food_store_tp6 -At -c "SELECT count(*) FROM detalle_pedido;"
& $psql -d food_store_tp6 -At -c "SELECT count(*), sum(cantidad) FROM detalle_pedido;"

# 2. Revertir la Parte 2 (el cubo y sus disparadores)
& $psql -d food_store_tp6 -v ON_ERROR_STOP=1 -c "BEGIN; DROP TABLE IF EXISTS fact_venta_categoria_dia CASCADE; COMMIT;"

# 3. Revertir la Parte 1 (estructuras nuevas; la tabla original se conserva)
& $psql -d food_store_tp6 -v ON_ERROR_STOP=1 -c "BEGIN; DROP VIEW IF EXISTS control_lote_almacen_compat; DROP TABLE IF EXISTS control_lote; DROP TABLE IF EXISTS responsable_deposito; COMMIT;"

# 4. Verificar que la fuente de verdad no cambió
& $psql -d food_store_tp6 -At -c "SELECT count(*) FROM detalle_pedido;"
& $psql -d food_store_tp6 -At -c "SELECT to_regclass('fact_venta_categoria_dia');"
```

- [x] La reversión de la Parte 2 es `DROP TABLE ... CASCADE`: se lleva los
      disparadores y deja la fuente de verdad intacta.
- [x] La reversión de la Parte 1 no toca `control_lote_almacen` (tabla original
      usada como oráculo).
- [x] Reaplicar = volver a ejecutar el script; el `DROP` + backfill reconstruye
      el cubo y el `EXCEPT` vuelve a dar 0 filas.
- [x] Dejar constancia en `TP6/TP6_Food_Store.pdf` §Reversibilidad.

## 5. Cierre

- [x] `TP6/TP6_Food_Store.pdf` con los dos planes completos y las mediciones.
- [x] `.sql` en `TP6/` y copias en la raíz del repo.
- [x] Referencia en `README.md` (sección TP6 / Unidad 4).
- [x] Fila de U4 en `BITACORA.md` (prompt, propuesta de la IA y corrección
      humana).
- [x] Requisitos, diseño, tareas y reversión en `docs/kiro_u4/`.

## 6. Pendientes conocidos

- [ ] **F-U4-4 (Alta):** corregir la descomposición de la Parte 1. La versión
      entregada usa `control_lote(lote_id, deposito_id)`; la reunión con
      `responsable_deposito` por `deposito_id` es con pérdida en general. La
      alternativa sin pérdida es `control_lote(lote_id, responsable_control_id)`.
      Requiere actualizar el script, la vista, el informe U4 y la defensa.
- [ ] El informe U4 cita el esquema de `food_store_tp5`; si se reproduce desde
      `seed.sql` los volúmenes cambian y las cifras de filas no son
      comparables. Se documenta como condición de reproducción.
- [ ] `fact_venta_categoria_dia` no tiene política de retención: el histórico
      crece una fila por día y categoría. No es un problema al volumen actual;
      queda como deuda para U6.
