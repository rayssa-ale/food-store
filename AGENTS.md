# AGENTS.md

Repositorio del proyecto integrador **Food Store** (cátedra Base de Datos, UTN).
Los scripts PostgreSQL sustentan los TP de integridad, concurrencia, seguridad y mantenimiento.

## Estructura

- `schema.sql` — DDL definitivo (enums, 5 tablas, 3 índices; reglas R1–R7).
- `seed.sql` — carga inicial (3 categorías, 6 productos, 3 clientes, 3 pedidos, 5 líneas).
- `sql/restricciones.sql` — triggers de reglas de negocio evaluadas en TP2 Parte 1.
- `sql/roles.sql`, `sql/simulacro_incidente.sql`, `sql/usuario_anon.sql` —
  Unidad 5 (seguridad, auditoría, incidente y anonimización). La
  especificación está en `docs/kiro_roles_spec/`.
- `TP6/` — Unidades 4 y 6.
  - Unidad 4: `tp_fnbc_control_lote.sql` (FNBC),
    `tp_desnormalizacion_top_categorias.sql` (cubo con disparadores),
    `TP6_Food_Store.pdf` (informe) y `carga_dia_actual.sql`, que siembra el
    día corriente para que el `EXPLAIN ANALYZE` del reporte no mida un
    conjunto vacío. Los .sql también están en la raíz del repo.
  - Unidad 6: `SPEC_U6.md`, `backup_foodstore.ps1`, `restore_test.ps1`,
    `sql/health_check.sql`, `sql/maintenance.sql`, `sql/validation_drill.sql`,
    `informe_u6.pdf` y `anexo_evidencias_u6.pdf`. `backups/` y `logs/` no se
    versionan.
- `Trabajo Practico - Unidad 7/` — Unidad 7 (NoSQL): migración a MongoDB,
  consultas cruzadas, informe y PDF.
- `movil/` — Unidad 8 (entrega): `schema_sqlite.sql`, `pruebas_sqlite.sql`,
  `semaforo.sql`, `v_snapshot_movil.sql`, `exportar_snapshot.sql`,
  `verificacion_servidor.sql`, `servidor_snapshot.csv`,
  `foodstore_movil.db` y `evidencias/`. La tablet nunca escribe en PostgreSQL;
  precios en centavos (`INTEGER`), tablas `STRICT` y baja lógica local
  (`eliminado = 1`) para no romper la FK del borrador.
- `docs/kiro/` — Unidad 8: `requirements.md` (EARS), `design.md` y `tasks.md`.
- `docs/informe.pdf`, `docs/informe_u8.md`, `docs/generar_informe_u8.py`,
  `docs/bitacora_ia.md` y `docs/DUIA.md` — entrega U8.
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

# U6: respaldo, health check, mantenimiento y simulacro (Ivana, en TP6/)
& $psql -U postgres -h localhost -d foodStore -f TP6/sql/health_check.sql
& $psql -U postgres -h localhost -d foodStore -f TP6/sql/maintenance.sql
.\TP6\backup_foodstore.ps1
.\TP6\restore_test.ps1

# U8: instantánea para la tablet y verificación del servidor
# createdb -U postgres -T foodstore foodstore_u8
& $psql -U postgres -h localhost -d foodstore_u8 -f movil/v_snapshot_movil.sql
& $psql -U postgres -h localhost -d foodstore_u8 -f movil/exportar_snapshot.sql
& $psql -U postgres -h localhost -d foodstore_u8 -f movil/verificacion_servidor.sql
# SQLite: ejecutar schema_sqlite.sql, importar servidor_snapshot.csv en
# snapshot_servidor y ejecutar semaforo.sql (DB Browser o módulo sqlite3).
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