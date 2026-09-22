# Protocolo de seguridad — Food Store (TP2, Base de Datos II)

Objetivo: **nunca perder ni corromper los datos del proyecto**. Toda
actividad (especialmente cambios estructurales y exports de la
herramienta IA) se ejecuta sobre una **copia de trabajo**, dentro de
**transacciones**, y con **respaldo previo**.

Entorno real del laboratorio:

- Motor: PostgreSQL 18 local (servicio `postgresql-x64-18`).
- Conexión: `-U postgres -h localhost` (auth scram-sha-256).
- `psql` no está en el PATH → ruta completa:
  `C:\Program Files\PostgreSQL\18\bin\psql.exe`
  (ídem `pg_dump.exe`, `createdb.exe`).
- Bases: `food_store_prod` (fuente de verdad del negocio) y
  `food_store_dev` (**copia de trabajo**). Hoy sólo existe la copia.

---

## Paso 1 — Copia: trabajar siempre sobre la copia

Nunca ejecutar DDL ni experimentos sobre la base real. La copia de
trabajo se crea clonando el esquema:

```powershell
$psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'

# 1a. Clonar la base real (crea food_store_dev idéntica a la fuente)
& $psql -U postgres -h localhost -d postgres -c `
  "CREATE DATABASE food_store_dev TEMPLATE food_store_prod;"

# 1b. (o, si se parte de cero) crear vacía y cargar esquema + datos
& $psql -U postgres -h localhost -d postgres -c "CREATE DATABASE food_store_dev;"
& $psql -U postgres -h localhost -d food_store_dev -f schema.sql
& $psql -U postgres -h localhost -d food_store_dev -f seed.sql
```

Convención usada en el lab: `food_store_dev` = base de trabajo;
el `seed.sql` identifica cada prueba con ids explícitos.

## Paso 2 — Transacción: probar, medir, y recién entonces COMMIT

Cada cambio se valida dentro de una transacción. Si algo falla o el
resultado no es el esperado, `ROLLBACK` y no queda ninguna huella.

```powershell
& $psql -U postgres -h localhost -d food_store_dev -f sql/restricciones.sql
```

El script `sql/restricciones.sql` (Parte 1) se escribió pensado para
validarse dentro de la transacción de prueba:

```sql
BEGIN;
\i sql/restricciones.sql            -- se aplican los triggers
-- ... pruebas con INSERT/UPDATE válidos e inválidos ...
-- si todo fue razonable:
COMMIT;
```

Regla de oro: **una escritura que no se puede revertir no se
ejecuta fuera de una transacción supervisada**.

## Paso 3 — Respaldo: dump antes de tocar la estructura

Antes de cualquier cambio estructural (y al iniciar la Parte 1) se
genera un respaldo de la copia de trabajo:

```powershell
$pgdump = 'C:\Program Files\PostgreSQL\18\bin\pg_dump.exe'
& $pgdump -U postgres -h localhost -d food_store_dev -f `
  "respaldos/food_store_dev_20260922.sql"
```

- Los respaldos viven en `respaldos/` y **no se versionan** en Git.
- Restauración de emergencia:
  `createdb food_store_dev; psql ... -d food_store_dev -f respaldos/<archivo>.sql`

---

## Cómo se aplicó este protocolo en el TP2

| Paso | Evidencia |
|------|-----------|
| Copia | DB `food_store_dev` creada; schema + seed cargados (3/6/3/3/5 filas). |
| Respaldo | `respaldos/food_store_dev_20260922.sql` (`pg_dump`, 10,9 KB) generado antes de la Parte 1. |
| Transacción | `sql/restricciones.sql` aplicado y probado dentro de `BEGIN/COMMIT`; casos inválidos verificados en transacciones que se revirtieron. |
| Git | Cada parte con commit descriptivo; la Parte 1 revisó `git diff` del script antes de commitear. |