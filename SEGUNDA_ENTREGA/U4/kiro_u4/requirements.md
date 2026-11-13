# requirements.md — Unidad 4 (TP6)

**Proyecto:** Food Store · **Materia:** Base de Datos II (UTN FRM)
**Unidad:** 4 — Forma Normal de Boyce-Codd y desnormalización controlada
**Entregables:** `TP6/tp_fnbc_control_lote.sql`, `TP6/tp_desnormalizacion_top_categorias.sql`,
`TP6/TP6_Food_Store.pdf`

## Objetivo

Dejar registrada, antes de escribir código, la especificación de las dos piezas
de la Unidad 4: (1) el análisis y la descomposición FNBC sobre
`control_lote_almacen` y (2) la desnormalización controlada del reporte
«top 5 categorías del día», con su mecanismo de sincronización y su plan de
reversión.

## Alcance

- Aplica sobre una **copia de trabajo** (`food_store_tp6`), nunca sobre
  `foodstore` ni sobre la base de producción.
- No modifica `schema.sql` ni `seed.sql`: las dos piezas son autocontenidas y
  reversibles.
- No cubre seguridad de roles (U5), respaldo/restauración (U6), NoSQL (U7) ni
  la tablet (U8).

## Requisitos funcionales (EARS)

### Parte 1 — FNBC

- **R-U4-01.** El sistema deberá declarar explícitamente el conjunto de
  dependencias funcionales del caso `control_lote_almacen`, con su lectura de
  negocio, antes de evaluar cualquier forma normal.
- **R-U4-02.** El sistema deberá calcular la clausura de cada subconjunto de
  atributos y enumerar **todas** las claves candidatas, no solo la PK elegida.
- **R-U4-03.** El sistema deberá distinguir atributos primos de no primos y
  justificar por qué 3FN y FNBC pueden separarse en este caso.
- **R-U4-04.** El sistema deberá demostrar con SQL, dentro de `SAVEPOINT`s, las
  tres anomalías (inserción, actualización y borrado) que habilita el esquema
  no normalizado, y deberá revertir cada demostración con `ROLLBACK TO`.
- **R-U4-05.** El sistema deberá descomponer el esquema en
  `responsable_deposito` y `control_lote`, ambas en FNBC.
- **R-U4-06.** El sistema deberá probar la reunión sin pérdida con el criterio
  de superclave **y con un contraejemplo con dos responsables en el mismo
  depósito**. Un `EXCEPT` 0/0 sobre una instancia con un responsable por
  depósito no es prueba suficiente (ver F-U4-4).
- **R-U4-07.** El sistema deberá exponer una vista de compatibilidad
  `control_lote_almacen_compat` con el mismo esquema y las mismas filas que la
  tabla original.

### Parte 2 — Desnormalización controlada

- **R-U4-08.** El sistema deberá medir el plan de la consulta normalizada de
  4 tablas con `EXPLAIN (ANALYZE, BUFFERS)` antes de proponer cualquier cambio.
- **R-U4-09.** El sistema deberá crear `fact_venta_categoria_dia` con grano
  `(fecha, categoria_id)`, montos `NUMERIC(14,2)` y PK natural compuesta.
- **R-U4-10.** El sistema deberá mantener el cubo con disparadores en la misma
  transacción que la escritura de origen: camino caliente O(1) por línea y
  camino frío con recálculo del día para cambios de alcance ancho.
- **R-U4-11.** El sistema deberá aplicar la misma regla de negocio que la
  consulta original (una línea cuenta si su pedido no está `CANCELADO`).
- **R-U4-12.** El sistema deberá poblar el histórico con el mismo `SELECT` de
  la consulta auditora y deberá comparar antes/después con `EXCEPT`
  bidireccional.
- **R-U4-13.** El sistema deberá demostrar que el reporte lee el cubo
  (3 filas, 6 buffers) y no las 549.529 filas de `detalle_pedido`.

### Reversibilidad

- **R-U4-14.** El sistema deberá documentar y ejecutar el plan de reversión de
  cada pieza, de modo que el estado previo quede restaurado y verificado con
  conteos.

## Requisitos no funcionales

- **R-U4-15.** Ninguna decisión de diseño se acepta sin un plan de ejecución o
  una medición que la respalde.
- **R-U4-16.** Los scripts deben ser idempotentes en su primera mitad
  (`DROP IF EXISTS` antes de crear) y terminar con `COMMIT` explícito.
- **R-U4-17.** El costo de escritura debe medirse: el cubo no puede degradar
  el camino caliente del mostrador.
- **R-U4-18.** Los predicados de fecha usan rango semiabierto
  (`>= fecha AND < fecha + 1 day`); `fecha = CURRENT_DATE` se considera un
  error de medición porque devuelve 0 filas sobre `TIMESTAMPTZ`.
- **R-U4-19.** No se usa `VACUUM FULL` ni bloqueos exclusivos prolongados
  (política que luego retoma U6).

## Fuera de alcance

- Reescribir `pedido` para almacenar `total`: el esquema documenta que es
  derivable y que almacenarlo viola 3FN.
- Convertir el cubo en vista materializada: exige `REFRESH` y no soporta el
  camino incremental en tiempo real.
- Sincronización del cubo por lotes nocturnos: se descarta por latencia del
  panel.

## Criterios de aceptación

| # | Criterio | Evidencia |
|---|---|---|
| 1 | Las claves candidatas del caso están enumeradas y justificadas | `tp_fnbc_control_lote.sql` §(b) |
| 2 | Se demuestra que el esquema cumple 3FN y no FNBC | §(c) |
| 3 | Las tres anomalías se ejecutan y se revierten | §(d), `SAVEPOINT`/`ROLLBACK TO` |
| 4 | La descomposición es sin pérdida: criterio de superclave + contraejemplo con dos responsables por depósito | `tp_fnbc_control_lote.sql` §(e), §(f) y bloque CONTRAEJEMPLO (F-U4-4 corregido) |
| 5 | El plan antes/después está medido | `EXPLAIN ANALYZE` en ambos scripts |
| 6 | El cubo coincide con la consulta auditora | `EXCEPT` bidireccional |
| 7 | El plan de reversión deja el estado anterior verificado | `tasks.md` §Reversión |
