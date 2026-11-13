# BITÁCORA — Unidades 5 y 6 (roles, auditoría, incidente, anonimización; respaldo y recuperación)

Registro de uso de IA (OpenCode) durante la segunda entrega del TPI.
Cada fila indica qué se pidió, qué propuso la IA y **cómo se validó o corrigió**
antes de incorporarlo. La IA se usó como asistente; las decisiones y la
verificación final son humanas.

| # | Parte | Prompt (resumen) | Respuesta relevante de la IA | Validación / corrección humana |
|---|---|---|---|---|
| A-1 | A | "Diseñá los roles y permisos para la app y el área de datos." | Propuso un rol único `app` con `GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public`. | **Rechazado.** Viola mínimo privilegio (incluye `INSERT/UPDATE/DELETE` y el hash). Se separó en 5 roles de grupo + 2 logins y se otorgó sólo lo necesario. |
| A-2 | A | "Asegurá que la app no pueda leer el hash." | Propuso `GRANT SELECT ON usuario` a nivel tabla, asumiendo que "la app no consulta `contrasena`". | **Corregido.** A nivel tabla el hash queda expuesto. Se pasó a permisos **por columna** excluyendo `contrasena`; verificado con `information_schema.column_privileges`. |
| A-3 | A | "Verificá separación de tareas entre datos y auditoría." | Propuso hacer `admin_datos` miembro de `rol_auditor` "para simplificar". | **Rechazado.** Un administrador que puede leer/alterar la auditoría rompe la separación. Se dejó fuera; `pg_has_role('admin_datos','rol_auditor','MEMBER') = f`. |
| A-4 | A | "Revisá que `rol_reportes` no acceda a PII." | Propuso mantener el `GRANT` sobre `v_reporte_pedidos_cliente` porque "ya es una vista de reporte". | **Rechazado.** La vista expone nombre/apellido/email y anula la restricción por columna de `cliente`. Se revocó para reportes y se conservó sólo para la app; `has_table_privilege('rol_reportes', vista, 'SELECT') = f`. |
| A-5 | A | "Revisá los privilegios por defecto." | Propuso `ALTER DEFAULT PRIVILEGES ... GRANT SELECT ON TABLES TO rol_reportes`. | **Rechazado.** Una tabla futura puede contener PII; se dejó *default deny* y otorgamiento explícito. `pg_default_acl` quedó vacío. |
| B-1 | B | "Activá la auditoría nativa y explicá qué aporta." | Propuso `log_statement='all'`, `log_connections=on`, `log_disconnections=on` y prefijo `%m [%p] %u@%d %h`. | **Aceptado con advertencia.** `all` registra literales (mails/claves). Se documentó que en producción va `mod`/`ddl` + `pgaudit`; el log compartido se anonimizó. |
| B-2 | B | "Probá un login fallido real." | Propuso conectar como `app_web` con `psql`; el primer intento quedó esperando la clave. | Se usó `-w` y una clave efímera por `ALTER ROLE` (no versionada). El `FATAL` quedó registrado y se extrajo el fragmento. |
| C-1 | C | "Armá el simulacro con escalamiento y pruebas negativas." | Propuso bloques `DO` con `GRANT admin_datos` y `RAISE NOTICE` para informar el resultado. | **Corregido.** `NOTICE` no llega al log del servidor (queda bajo `log_min_messages`), así que la evidencia no mostraba el bloqueo. Se cambió a `RAISE WARNING` y se re-ejecutó; el log ahora prueba `ESCALAMIENTO BLOQUEADO`. |
| C-2 | C | "Anonimizá el fragmento del log para compartirlo." | El primer script reemplazó `app_web@food` dentro del prefijo `app_web@food_store_u5`, corrompiendo el log. | **Detectado al leer la salida.** Se restringió el reemplazo a correos **citados** (`'...'`) y se excluyó el prefijo `usuario@base`; se regeneró el archivo. |
| C-3 | C | "Reconstruí el incidente sólo con el log anonimizado." | Afirmó IP externa, contraseña comprometida y exfiltración. | **Marcado como no sustentado.** El log muestra `::1` (localhost), no prueba cómo se obtuvo la clave ni que las filas se exportaran. Se corrigió el informe y se separó "hipótesis" de "hecho". |
| C-4 | C | "Proponé contención." | Propuso revocar `rol_app_lectura` y bloquear la IP. | **Ajustado.** Revocar el rol global rompe la app; la contención se dirigió: rotar credencial, revisar el login exitoso, revisar el `SELECT` masivo y agregar bloqueo por intentos. Decisión humana. |
| D-1 | D | "Anonimizá `usuario` y verificá que el agregado no cambie." | Propuso reemplazar nombre/mail pero **conservar el `id` real**; también sugirió valores aleatorios. | **Corregido.** El `id` permite re-identificar por JOIN y los valores aleatorios rompen la equivalencia. Se usó `row_number()` determinista y se preservó rol/activo/mes; verificado con `EXCEPT` en ambos sentidos → 0 filas. |
| E-1 | E | "Organizá el historial Git por partes." | Propuso un commit por parte (A–E) con mensajes `feat(u5): ...`. | **Pendiente de aprobación.** No se commitea sin pedido explícito; los mensajes propuestos están en la sección de Git. |

## Caso más significativo (IA propone un permiso más amplio)

En **A-1/A-2** la IA propuso `GRANT ALL PRIVILEGES ON ALL TABLES` y, al pedirle
"que la app no lea el hash", insistió con `GRANT SELECT` a nivel tabla. Ambas
opciones **habrían expuesto `contrasena`** y dado escritura innecesaria. Se
detectó leyendo el SQL propuesto línea por línea y contrastándolo con la
matriz de privilegios; la corrección fue otorgar **por columna** y verificar
el resultado con `has_column_privilege`/`column_privileges`, no con la
intención declarada.

El mismo patrón apareció en **A-4/A-5**, ya no en una tabla sino en una
**vista** y en los **privilegios por defecto**: `v_reporte_pedidos_cliente`
expone PII y el `GRANT` a `rol_reportes` habría sido una fuga; el `SELECT`
automático sobre tablas futuras habría repetido el problema con cada tabla
nueva. La lección es que el mínimo privilegio se verifica sobre **todo objeto
consultable** (tabla, vista, función) y sobre **objetos futuros**.

## Caso más significativo (IA afirma de más)

En **C-3** la reconstrucción fue plausible pero incluyó tres afirmaciones que
el log **no** sustenta (IP externa, contraseña comprometida, exfiltración).
Se contrastó cada afirmación con la línea correspondiente del log y se
reclasificó como hipótesis. Es el principal riesgo de usar IA en un informe de
incidente: un texto convincente puede convertirse en "hecho" si no se verifica.

## Unidad 6 — respaldo, mantenimiento y recuperación

| # | Parte | Prompt (resumen) | Respuesta relevante de la IA | Validación / corrección humana |
|---|---|---|---|---|
| U6-1 | 1–2 | "Armá la SPEC y los scripts de backup, health check, maintenance y restore." | Generó la SPEC y la primera versión de los cuatro scripts con `pg_dump -Fc`, guardas de destino y logs. | **Revisado.** Se agregaron conteos previos al respaldo, verificación con `pg_restore --list`, `-w` y la guarda `*_restore_test`; se ejecutó todo manualmente. |
| U6-2 | 2 | "Elegí la acción de mantenimiento." | Propuso inicialmente justificar `ANALYZE` diciendo que "el planner no tenía estadísticas"; también evaluó `VACUUM FULL`. | **Corregido.** El health check mostró que `pg_class.reltuples` ya tenía estimaciones copiadas por `createdb -T`; sólo `categoria` estaba en -1 y `pg_stat_user_tables` no tenía historial. Se descartó `VACUUM FULL` y se justificó `ANALYZE` con la observación real; verificado antes/después. |
| U6-3 | 2 | "Corré el simulacro de restauración." | El primer `restore_test.ps1` abortó en `dropdb --if-exists`: PowerShell trató el NOTICE de stderr como error por `$ErrorActionPreference='Stop'`. | **Detectado en la salida.** Se cambió el manejo de stderr nativo a `Continue` + verificación de `$LASTEXITCODE`; el segundo intento restauró y validó todo. |
| U6-4 | 2–3 | "Revisá qué falta después de restaurar." | El restore mostró que autovacuum autoanalizó las tablas grandes, pero `categoria` quedó sin `pg_statistic`; además `--no-owner --no-privileges` dejó sólo a `postgres` con privilegios. | **Confirmado con consultas.** Se agregó al runbook `ANALYZE;` + reaplicar `sql/roles.sql`/grants (o restaurar sin `--no-privileges`). Evidencia en `U6/evidencias/`. |
| U6-5 | 3 | "Generá el informe de una página." | Generó `informe_u6.pdf` con reportlab a partir de `informe_u6.md`; incluye RTO/RPO, validaciones, problema y mejora. | **Verificado.** `pypdf` confirma 1 página; se contrastaron los valores con los logs/JSON y se corrigieron las cifras. |

### Caso más significativo (U6: el diagnóstico se generaliza de más)

En **U6-2** la IA pasó de "las estadísticas no se copiaron" a "el planner no tiene
estadísticas", pero el health check mostró que `pg_class.reltuples` sí tenía
estimaciones para las tablas grandes; el problema real era más acotado
(`categoria` sin analizar y `pg_statistic` ausente tras un restore lógico). La
corrección fue contrastar `pg_stat_user_tables`, `pg_class.reltuples` y
`pg_statistic` por separado antes de elegir la acción. En **U6-4** el restore
confirmó el riesgo de `--no-owner --no-privileges`: los datos están, pero la app
no tiene permisos. La lección: un restore "OK" en conteos no es un restore listo
para producción.

## Unidad 8 - tablet SQLite y semaforo

| # | Parte | Prompt (resumen) | Respuesta relevante de la IA | Validacion / correccion humana |
|---|---|---|---|---|
| U8-1 | 1.b | "Disena las tablas SQLite con precio y stock." | Proponia `REAL`, sin `STRICT` y sin centavos. | **Corregido.** `precio_centavos INTEGER`, `STRICT`, `CHECK` y `PRAGMA foreign_keys = ON`; se creo la base desde cero y se ejecutaron las pruebas. |
| U8-2 | 2.b | "Escribe el semaforo que compara solicitudes." | Actualizaba todas las solicitudes, incluso las ya aprobadas. | **Corregido.** Solo `PENDIENTE`; `evaluado_en` no cambia al repetir (C6). Evidencia en `movil/evidencias/c6_reevaluacion.txt`. |
| U8-3 | 2.a | "Importa el CSV de psql en SQLite." | Suponia booleanos `0/1`. | **Corregido.** psql exporta `t/f`; se conservan como texto y se normalizan con `CASE`. Verificado en C1 y C4. |
| U8-4 | 2.c | "Que hago cuando el servidor da de baja un producto?" | Borraba la fila de `producto_cache`. | **Descartado.** Se conserva con `eliminado = 1` para no romper la FK y mantener la lapida (C4). |
| U8-5 | 3.c | "Revisa los scripts de la cursada" (OpenCode Plan). | Probo un indice sobre `detalle_pedido(cantidad)` y `VACUUM FULL` periodico. | **Descartados.** El plan sigue `Seq Scan` con y sin indice; `VACUUM FULL` bloquea. Se aceptaron las correcciones de fecha/rango y de ACLs post-restore. Evidencia en `movil/evidencias/code_review_db.txt`. |

### Caso mas significativo (U8: la tablet no debe borrar la lapida)

En **U8-4** la IA propuso eliminar la fila local del producto dado de baja. Eso
rompe la FK de `item_borrador` y borra la prueba del motivo del rechazo. Se
corrigio a una baja logica local (`eliminado = 1`, `disponible = 0`): el
catalogo disponible ya no la muestra, pero la fila queda para C4. La leccion es
que la cache tambien necesita una politica de bajas, no solo de altas.

## Estado de Git

**U8 quedó commiteada** en `4b97f27` (esquema SQLite, instantánea y semáforo),
`c6837c7` (casos C1–C7, base de la tablet y evidencias), `46a6634`
(requisitos/design/tasks de Kiro, bitácora de IA y DUIA) y el commit de cierre
con el informe final y el índice actualizado.

**U5 y U6 siguen sin commit** (requieren aprobación explícita). Estructura
propuesta:

1. `feat(u5): base de usuarios, autenticación y auditoría de login`
2. `feat(u5): roles y permisos con mínimo privilegio (Parte A)`
3. `feat(u5): auditoría nativa y evidencia de prueba (Parte B)`
4. `feat(u5): simulacro de incidente y log anonimizado (Parte C)`
5. `feat(u5): anonimización y verificación de equivalencia (Parte D)`
6. `docs(u5): informes de auditoría/incidente y bitácora (Parte E)`
7. `feat(u6): respaldo custom, health check y mantenimiento seguro`
8. `test(u6): simulacro de restauración con RTO/RPO y validaciones`
9. `docs(u6): SPEC, informe y evidencias del simulacro`
