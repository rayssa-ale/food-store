# Declaración de Uso de IA (DUIA) — Segunda entrega (U4 a U8)

**Materia:** Base de Datos II — UTN FRM
**Proyecto:** Food Store · **Equipo G**
**Integrantes:** Ivana Gutiérrez, Rayssa Alejo, Julieta Chávez, Brisa Muñoz
**Entrega:** segunda entrega del TPI (Unidades 4 a 8)
**Fecha:** noviembre de 2026

## 1. Herramientas y alcance

| Herramienta | Uso | Unidades |
|---|---|---|
| **Kiro** | `requirements.md`, `design.md` y `tasks.md` antes de escribir código | U4 (`docs/kiro_u4/`), U5 (`docs/kiro_roles_spec/`), U8 (`docs/kiro/`) |
| **OpenCode** | Generación de SQL/JS, revisión de scripts, agente Plan para code review y análisis forense del simulacro | U4, U5, U6, U7, U8 |
| **PostgreSQL 18** (17.11 en la práctica de auditoría) | Motor que validó cada propuesta relacional | U4, U5, U6 |
| **MongoDB / mongosh** | Motor documental de U7 | U7 |
| **SQLite 3.50.4** | Motor local de la tablet | U8 |

Regla de trabajo aplicada en toda la entrega: **la IA propone, el motor y las
mediciones deciden**. Cada sugerencia se leyó, se ejecutó y se contrastó antes de
incorporarla. Lo que no se puede explicar en la defensa se considera no
realizado.

## 2. Qué hizo la IA y qué corrigió el equipo

### U4 — FNBC y desnormalización

- Kiro redactó la especificación del caso y la descomposición.
- OpenCode propuso `fecha = CURRENT_DATE` para el filtro del día. **Corregido:**
  sobre `TIMESTAMPTZ` devuelve 0 filas; se usa rango semiabierto
  (`>= fecha AND < fecha + 1 day`).
- Se descartaron almacenar `pedido.total` (viola 3FN), usar una vista
  materializada (no sostiene el incremental) y un índice sobre
  `detalle_pedido(cantidad)` (el plan sigue `Seq Scan`).

### U5 — Seguridad, auditoría y anonimización

- Kiro relevó 4 roles de grupo, 2 logins y `rol_auditoria`.
- OpenCode propuso `GRANT ALL`, `SELECT` sobre todas las tablas —incluida
  `usuario`— «por simplicidad», `DELETE` en `rol_app_escritura` para «completar
  el CRUD» y revisar tablas del sistema. **Rechazado:** se mantuvo el permiso
  por columna, el *default deny* y `pg_default_acl` en 0 filas.
- En el análisis forense, OpenCode afirmó que `fn_autenticar`, `app_web` y
  `admin_datos` existían. **Corregido con el log crudo y el estado del motor:**
  la función y los roles no existían, `usuario` estaba vacía y toda la sesión
  corrió como superusuario `postgres` por `trust`.
- En el borrador del informe de anonimización, la IA afirmó 10.000 `ADMIN` y
  10.000 `USUARIO` sin consultar. **Corregido con la salida real:** 20.000
  `USUARIO`, 0 `ADMIN`, un solo mes de alta; se agregó el control por
  `rol, (id % 10)`.

### U6 — Respaldo y recuperación

- OpenCode generó los scripts de backup/restore, health check y mantenimiento.
- Propuso `VACUUM FULL` periódico. **Rechazado:** bloquea y reescribe; se usa
  `VACUUM (VERBOSE, ANALYZE)`.
- El code review detectó que `pg_restore --no-owner --no-privileges` deja
  `app_web` sin `SELECT` sobre `pedido`. **Corregido:** el runbook reaplica
  roles y `GRANT`s después del restore y verifica con `has_table_privilege`.

### U7 — NoSQL

- OpenCode generó el modelo documental, la migración y las consultas cruzadas.
- La respuesta de IA evaluada en la consigna afirmaba que «eliminar JOINs hace a
  MongoDB siempre más rápido» y que «la atomicidad del documento alcanza para el
  stock». **Refutado con documentación oficial y con el laboratorio:** la
  atomicidad de documento único no cubre el ciclo pedido + stock + pago; el
  dictamen es arquitectura híbrida con PostgreSQL como fuente de verdad.
- El code review detectó que el SQL equivalente usa `usuario`, `usuario_id`,
  `p.total` y `'TERMINADO'`, que no existen en el `schema.sql` publicado.
  **Documentado y corregido** en `consultas_postgresql_corregidas.sql`; el
  script original se conserva porque es la evidencia de lo ejecutado.

### U8 — Tablet y semáforo

- Kiro definió requisitos EARS, diseño y tareas del esquema SQLite.
- OpenCode propuso `precio REAL`, sin `STRICT` y sin centavos. **Corregido:**
  `precio_centavos INTEGER`, tablas `STRICT`, `CHECK` y `PRAGMA foreign_keys`.
- Propuso borrar la fila de `producto_cache` cuando el servidor da de baja un
  producto. **Descartado:** rompe la FK del borrador y oculta el motivo; se usa
  baja lógica local (`eliminado = 1`).
- Propuso reevaluar todas las solicitudes. **Corregido:** solo `PENDIENTE`.
- Supuso booleanos `0/1` en el CSV. **Corregido:** psql exporta `t/f`; se
  normalizan con `CASE`.

## 3. Datos y privacidad

No se envió a la IA ningún mail, teléfono, nombre real, hash de contraseña ni
fila completa de clientes.

- **U5:** el simulacro se analizó con un log **anonimizado**
  (`docs/log_simulacro_anonimizado.txt`); el log crudo se conservó localmente
  solo para el contraste humano.
- **U5:** `usuario_anon` usa datos sintéticos deterministas, sin `random()`,
  `now()` ni hash del dato real.
- **U7:** el seed de la migración usa nombres y contactos inventados. Queda como
  deuda reemplazar los dominios por `@example.test` antes de publicar.
- **U8:** la instantánea que viaja a la tablet contiene solo `producto_id`,
  nombre, precio en centavos, stock visto, disponible, eliminado y fecha de
  copia. Los borradores usan el alias local `vendedor_feria`.

## 4. Reglas respetadas

1. Se trabajó siempre sobre copias (`food_store_tp5`, `food_store_tp6`,
   `foodstore_test`, `foodstore_u8`, `foodstore_restore_test`), nunca sobre la
   base principal.
2. La tablet **nunca** escribe en PostgreSQL: `SIMULADO_APROBADO` no es una
   venta. `movil/verificacion_servidor.sql` muestra que pedidos, líneas,
   productos y stock no cambiaron.
3. Cada sugerencia se ejecutó antes de incorporarla; las cifras del informe
   salen de capturas reales, no de estimaciones de la IA.
4. Los hallazgos del code review tienen decisión y comprobación en
   `SEGUNDA_ENTREGA/code_review_segunda_entrega.md` y en las evidencias de cada
   unidad.
5. La bitácora completa, con prompts, aceptaciones y descartes, está en
   `BITACORA.md`.

## 5. Archivos generados con asistencia de IA

| Unidad | Archivos |
|---|---|
| U4 | `TP6/tp_fnbc_control_lote.sql`, `TP6/tp_desnormalizacion_top_categorias.sql`, `docs/kiro_u4/*` |
| U5 | `sql/roles.sql`, `sql/usuario_anon.sql`, `sql/simulacro_incidente.sql`, `docs/kiro_roles_spec/*` |
| U6 | `TP6/backup_foodstore.ps1`, `TP6/restore_test.ps1`, `TP6/sql/*.sql` |
| U7 | `Trabajo Practico - Unidad 7/migracion_mongodb.js`, `consultas_mongodb.js`, `consultas_postgresql.sql`, `consultas_postgresql_corregidas.sql` |
| U8 | `movil/schema_sqlite.sql`, `semaforo.sql`, `pruebas_sqlite.sql`, `v_snapshot_movil.sql`, `verificacion_servidor.sql`, `docs/informe.pdf`, `docs/kiro/*` |

Todos fueron revisados, ejecutados y contrastados contra el motor. La
responsabilidad del contenido final es del equipo.

## 6. Limitaciones declaradas

- La auditoría de U5 es nativa (a nivel sentencia), no fila por fila como
  `pgaudit`.
- La anonimización de U5 preserva utilidad analítica agregada; no es
  k-anonimidad ni anonimización diferencial.
- El RPO de U6 depende de un respaldo diario; no hay PITR.
- El SQL original de U7 no es reproducible con el `schema.sql` publicado; la
  versión corregida sí.
- La descomposición de U4 tiene una observación de pérdida (F-U4-4) detectada en
  el code review; la corrección está propuesta y pendiente de decisión.
