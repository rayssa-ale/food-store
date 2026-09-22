# AGENTS.md

Repositorio del proyecto integrador **Food Store** (cátedra Base de Datos, UTN).
Los scripts PostgreSQL sustentan los TP de integridad y concurrencia (TP2).

## Estructura

- `schema.sql` — DDL definitivo (enums, 5 tablas, 3 índices; reglas R1–R7).
- `seed.sql` — carga inicial (3 categorías, 6 productos, 3 clientes, 3 pedidos, 5 líneas).
- `sql/restricciones.sql` — triggers de reglas de negocio evaluadas en TP2 Parte 1.
- `protocolo_seguridad.md` — protocolo copia / transacción / respaldo.
- `docs/` — informes de laboratorio (concurrencia, lectura crítica) y DUIA.
- `.kiro/` — steering docs compartidos con la herramienta Kiro.

## Comandos útiles (PostgreSQL 18 local, usuario `postgres`)

```powershell
# psql no está en el PATH: usar la ruta completa
$env:PGPASSWORD = '<contraseña>'
$psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'

# cargar esquema + datos sobre la copia de trabajo
& $psql -U postgres -h localhost -d food_store_dev -f schema.sql
& $psql -U postgres -h localhost -d food_store_dev -f seed.sql
& $psql -U postgres -h localhost -d food_store_dev -f sql/restricciones.sql

# copia / respaldo (ver protocolo_seguridad.md)
createdb -T plantilla copia_trabajo
pg_dump -U postgres copia_trabajo > respaldos/<fecha>.sql
```

## Convenciones del esquema

- Identificadores en `snake_case`; tablas en singular (`detalle_pedido`).
- Tipos de estado/pago cerrados con `ENUM` (`forma_pago`, `estado_pedido`).
- PK `BIGINT` sustituta generada con `GENERATED ALWAYS AS IDENTITY`.
- Montos siempre `NUMERIC(12,2)`, nunca `FLOAT`/`DOUBLE`.
- FKs con `ON DELETE RESTRICT`.
- Baja lógica con columna `activo BOOLEAN` (nunca borrado físico de
  categorías/productos/clientes con historial).
- Marca temporal `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`.

## Reglas de negocio (referencia para los triggers)

- R1 todo producto tiene exactamente una categoría. R2 todo pedido un cliente.
- R3 formas de pago cerradas. R4 precio de la línea congelado al facturar.
- R5 precio/stock no negativos. R6 email único. R7 sin borrados físicos.