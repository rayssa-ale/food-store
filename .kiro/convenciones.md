# Steering docs — Food Store

Documento de convenciones compartido con la herramienta Kiro
(TP2, Base de Datos II). Debe mantenerse alineado con `AGENTS.md`.

## Proyecto

Integrador **Food Store** sobre PostgreSQL 18 (local, usuario
`postgres`). Esquema de 5 tablas en singular, `snake_case`, enums
`forma_pago` y `estado_pedido`, PK `BIGINT` identity, montos
`NUMERIC(12,2)`, bajas lógicas con `activo`.

## Flujo de trabajo no destructivo (obligatorio)

1. Trabajar SIEMPRE sobre la **copia de trabajo** (`food_store_dev`),
   nunca sobre la base de producción.
2. Antes de cambios estructurales: `pg_dump` a `respaldos/`.
3. Probar cada escritura dentro de una **transacción** y revisar el
   resultado antes de `COMMIT`.
4. Versionar en Git cada ejercicio con commit descriptivo.

## Reglas de negocio (referencia)

- R1 todo producto tiene exactamente una categoría.
- R2 todo pedido un cliente.
- R3 formas de pago cerradas.
- R4 precio de la línea congelado al facturar.
- R5 precio/stock no negativos.
- R6 email único.
- R7 sin borrados físicos.

## Concurrencia

Aislación por MVCC. Lecturas: `READ COMMITTED` (por defecto) vs
`REPEATABLE READ`. Bloqueos fila con `SELECT ... FOR UPDATE`.
Interbloqueo = `SQLSTATE 40P01`.