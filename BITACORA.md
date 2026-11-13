# BITACORA.md

Bitácora consolidada de la **segunda entrega (Unidades 4 a 8)**. Registra el
pedido a la IA, la respuesta relevante y la validación o corrección humana. Las
filas de U4–U7 resumen interacciones documentadas en los scripts, informes y en
`SEGUNDA_ENTREGA/code_review_segunda_entrega.md`; las de U5 y U8 conservan el
registro original del equipo.

## Unidad 4 — FNBC y desnormalización controlada

| # | Parte | Pedido a la IA (resumen) | Respuesta relevante | Validación / corrección humana |
|---|---|---|---|---|
| U4-1 | 1 (FNBC) | «Especificá el caso `control_lote_almacen`, calculá claves candidatas y escribí el script con las anomalías.» | Redactó la descomposición y las tres anomalías, pero en la primera versión asumió que un esquema en 3FN ya estaba en FNBC y filtró el día con `fecha = CURRENT_DATE`. | **Corregido.** Se calcularon las clausuras y se demostró el caso 3FN sin FNBC (FD2 con determinante no superclave). El filtro pasó a rango semiabierto: con `= CURRENT_DATE` el plan medía 0 filas; con rango, 12.269 pedidos. |
| U4-2 | 2 (desnormalización) | «¿Conviene guardar `pedido.total` o materializar el top 5 con una vista materializada?» | Propuso almacenar `total` y usar una MV con `REFRESH` periódico. | **Descartado.** `total` introduce dependencia transitiva (viola 3FN) y la MV no sostiene el camino incremental en tiempo real. Se eligió el cubo `fact_venta_categoria_dia` con disparadores caliente/frío y backfill con la misma agregación del auditor. |
| U4-3 | 2 (medición) | «¿Qué índice acelera la consulta del top 5?» | Propuso un índice sobre `detalle_pedido(cantidad)`. | **Descartado con el plan real.** La agregación sigue con `Seq Scan` porque el predicado no filtra por `cantidad`; el costo estaba en el volumen explorado, no en el acceso. Se resolvió con el cubo: 138,0 ms → 0,118 ms. |
| U4-4 | 1 (code review) | «Revisá la prueba de reunión sin pérdida del script.» | Aceptó que `{DepositoID}` fuera clave de `responsable_deposito` y tomó el `EXCEPT` 0/0 como prueba de corrección. | **Corregido (F-U4-4).** `{DepositoID}+ = {DepositoID}` no es superclave de ninguna de las dos relaciones: la descomposición era con pérdida y el 0/0 dependía de la instancia. Se corrigió a `control_lote(lote_id, responsable_control_id)`, se agregó el contraejemplo ejecutable (4 filas contra 2 del original) y se declaró el costo (FD1 no preservada). La lógica fue validada por simulación; la reejecución en el motor quedó pendiente por no disponer de contraseña en la sesión de cierre. |

## Unidad 5 — Seguridad, auditoría y anonimización

| Prompt enviado a la IA | Respuesta relevante recibida (resumida) | Validación o corrección humana aplicada |
|-------------------------|------------------------------------------|------------------------------------------|
| «Parte A: redactar en Kiro la especificación breve (requirements + design) de los roles de Food Store y el `roles.sql` con `CREATE ROLE`, `GRANT`/`REVOKE`, al menos un permiso a nivel de columna y `ALTER DEFAULT PRIVILEGES`. Luego, actuar como auditor de seguridad PostgreSQL y auditar `roles.sql` bajo mínimo privilegio: permisos excesivos (`GRANT ALL`, permisos sobre todas las columnas), falta de restricciones y mejoras concretas.» | Kiro relevó cuatro roles de grupo, dos roles de login y un rol adicional de auditoría, con justificación por rol. En la auditoría, OpenCode propuso mantener `SELECT` sobre todas las tablas —incluida `usuario`— “por simplicidad”, agregar `DELETE` a `rol_app_escritura` para “completar el CRUD”, usar `GRANT ALL PRIVILEGES` y revisar también tablas del sistema. | Se rechazaron las propuestas amplias: se mantuvo el permiso a nivel de columna sobre `usuario` para `rol_app_lectura`, no se otorgó `DELETE` general y se descartó `GRANT ALL`. Se conservó `ALTER DEFAULT PRIVILEGES` y se dejó la verificación (`\du` e `information_schema.role_table_grants`) en `docs/verificacion_permisos.txt`. El caso quedó documentado en `docs/kiro_roles_spec/auditoria_opencode.md`. |
| «Parte B: activar y probar la auditoría nativa de PostgreSQL; guardar el fragmento del log en `docs/log_auditoria_prueba.txt` y redactar `docs/informe_auditoria.md`.» | Se detectó PostgreSQL 17.11 y las rutas reales (`data/postgresql.conf`, `data/pg_hba.conf`, `data/log/`). Se identificó que `food_Store` está vacía (0 filas) y que `foodstore_test` es la única base Food Store poblada; se propuso usarla y documentar la diferencia. | Se aceptó usar `foodstore_test` para la prueba y se dejó constancia de que `food_Store` existe pero no tiene datos. Se verificó que no se tocaran datos de negocio existentes. |
| «Aplicá los parámetros de auditoría sin reiniciar y mostrá la verificación». | Se aplicó `ALTER SYSTEM` para `log_connections`, `log_disconnections`, `log_statement` y `log_line_prefix`; `pg_reload_conf()` devolvió `t`. `SHOW` y `pg_settings` confirmaron `source = configuration file` y `sourcefile = postgresql.auto.conf`. | Se revisó que `log_statement = all` fuera una desviación deliberada de `mod` (para evidenciar el `SELECT`) y se documentó que `ddl,mod` no es un valor válido en PostgreSQL 17. |
| «Ejecutá la secuencia de lectura/escritura y un login fallido, y capturá la evidencia». | Se ejecutaron `SELECT`, `INSERT` (categoría id 11) y `UPDATE` en `foodstore_test`; el login con contraseña incorrecta produjo `FATAL` y `DETALLE` con la línea 115 de `pg_hba.conf`. Se guardó el fragmento crudo (2.261 bytes) con SHA-256 `9C2C3C0131782C96A7E026241F2F5B183EBADB1F2ECB634F92C7FBCEA96E6C93`. | Se contrastó el fragmento con el log original y se confirmó el hash. Se verificó que `pg_hba.conf` quedó con `scram-sha-256` en `127.0.0.1/32` y `::1/128`; la regla temporal `trust` usada para la prueba quedó documentada y revertida. |
| «Redactá el informe con los Puntos 3 y 4». | Se generó `docs/informe_auditoria.md` con objetivo, entorno, configuración, verificación, secuencia, evidencia, análisis de límites vs. `pgaudit` y análisis del log como activo sensible (ACL de Windows, OneDrive, roles de PostgreSQL). | Se revisó que el informe no incluyera contraseñas ni datos de clientes, que distinguiera `pgaudit` (por sentencia/objeto) de la auditoría fila por fila, y que registrara el hallazgo de ACL permisiva y la ubicación en OneDrive como deuda de hardening. |
| «Enviar únicamente `log_simulacro_anonimizado.txt` a OpenCode para reconstrucción cronológica». | Se envió solo el fragmento anonimizado con prompt restrictivo. OpenCode reconstruyó cronología, identificó actores, detectó escalamiento parcial (`GRANT` fallido, `CREATE ROLE` exitoso luego `DROP`), advirtió sobre falta de `REVOKE` y propuso hipótesis de contención. La respuesta completa se guardó en `docs/respuesta_opencode_incidente.txt`. | Se verificó que el log anonimizado no contenía mails, nombres ni direcciones identificables. Se contrastó la respuesta con el log crudo: acertó en cronología, escalamiento y conexión `trust`; omitió que `fn_autenticar` no existe en `food_Store`, que `app_web` y `admin_datos` no existen, que `usuario` está vacía y que todo fue ejecutado por el superusuario `postgres`. Se rechazaron inferencias no sustentadas y la decisión de contención quedó a cargo del equipo, fundamentada en evidencia y en las Partes A y B. |
| «Parte D: anonimizar datos personales. Construir `usuario_anon` con datos sintéticos deterministas (sin `random()`/`now()`/hash del dato real), conservar `rol` con el mismo enum, truncar `created_at` a mes, `REVOKE ALL FROM PUBLIC`, script idempotente en `sql/usuario_anon.sql`. Luego pedir a OpenCode solo consultas agregadas de cantidad de usuarios por rol y por mes de alta: primero sobre `usuario_anon`, después la equivalente sobre `usuario`; sin `SELECT *`, sin columnas identificables, misma semántica y `ORDER BY`.» | OpenCode propuso las dos consultas con `date_trunc('month', created_at)`, filtro `eliminado = false`, `COUNT(*)` y `ORDER BY rol, mes_alta`, sin columnas identificables. En el borrador del informe asumió una distribución 10.000 `ADMIN` / 10.000 `USUARIO` sin haberla ejecutado. El prompt exacto y la respuesta quedaron registrados en `docs/verificacion_equivalencia.md`. | **Corrección real:** la ejecución mostró que las 20.000 filas son `USUARIO` (0 `ADMIN`); se descartó la distribución inventada y se reemplazaron las salidas del informe por las capturas reales. Se validó que ambas consultas tuvieran idéntica semántica (filtro, granularidad, `TimeZone`, `ORDER BY`) y solo agregados. Se agregó un control por `rol, (id % 10)` porque el mes es degenerado (un único valor, 2026-09). Se verificó: `count(*)` 20.000 en ambas tablas, `EXCEPT` bidireccional con 0 filas (rol/mes y control), no-fuga con 0 coincidencias en `mail`, `nombre+apellido`, `celular` y `contrasena`, y checksum md5 `703bd7edc6d5523f3093595e59ef90eb` idéntico tras reejecutar el script. Se documentó que es reemplazo determinista con utilidad analítica preservada, no k-anonimidad ni anonimización diferencial; `id` y el mes quedan como cuasi-identificadores; la equivalencia es solo agregada. `usuario` quedó intacta. |

---

## Análisis Crítico: Caso más significativo de error o imprecisión de la IA

El caso más significativo es el de la **Parte C**, porque la reconstrucción forense es el núcleo del trabajo y porque el error no fue un detalle de forma sino una lectura equivocada de la evidencia. OpenCode recibió únicamente el log anonimizado y asumió que los “intentos fallidos de inicio de sesión contra `fn_autenticar`” eran autenticaciones fallidas reales, cuando el log mostraba `ERROR: no existe la función fn_autenticar` y no `FATAL: autenticación fallida`. También asumió que `app_web` y `admin_datos` existían: el `GRANT admin_datos TO app_web` falló porque el rol `app_web` no existía, no porque el esquema de mínimo privilegio lo bloqueara. Además, mencionó a `postgres` pero no enfatizó que toda la sesión se ejecutó como **superusuario** por `trust` desde loopback, que es lo que explica el éxito de `CREATE ROLE` y cambia por completo la hipótesis de contención. Tampoco advirtió que la tabla `usuario` estaba vacía en `food_Store`.

Se lo detectó recién al contrastar la respuesta con el **log crudo**, con el script ejecutado y con el estado real del motor (`\du`, `\df`, `\dt`): la función y los roles no existían, la tabla tenía 0 filas y el usuario de sesión era `postgres`. Esa verificación permitió separar lo que la IA leyó del log de lo que infirió sin sustento. La decisión de contención final se tomó con esa evidencia y no se delegó a la IA.

Un segundo caso relevante ocurrió en la **Parte D**: al redactar el borrador del informe, la IA afirmó una distribución de **10.000 usuarios `ADMIN` y 10.000 `USUARIO`** que nunca había consultado. La ejecución real devolvió **20.000 `USUARIO` y 0 `ADMIN`**, en un único mes de alta. Se detectó porque la salida se ejecutó antes de documentar, se reemplazaron los valores supuestos por las capturas de terminal y se agregó la distinción entre el dominio del enum `rol` (que admite `ADMIN`) y la distribución observada (que no contiene ninguno). El control por `rol, (id % 10)` se incorporó justamente para que la equivalencia no dependiera de un agrupamiento mensual degenerado. Ambos casos quedaron registrados en las filas de la tabla y en `docs/informe_incidente.md` y `docs/verificacion_equivalencia.md`.

## Revisión del Historial de Git

El repositorio refleja un avance progresivo por partes: no hay un commit único con todo el trabajo, sino un commit descriptivo por cada una de las Partes A, B, C y D, en orden cronológico.

| Parte | Commit | Fecha | Mensaje |
|---|---|---|---|
| A | `3ade361` | 2026-10-24 14:46 | `Parte A: Diseno e implementacion de esquema de roles, permisos y especificacion Kiro` |
| B | `5144030` | 2026-10-24 15:57 | `Parte B: Activacion y pruebas de parametros de auditoria en PostgreSQL` |
| C | `3e5807c` | 2026-10-25 20:46 | `Parte C: Simulacro de incidente de seguridad y analisis critico de IA` |
| D | `09b82c0` | 2026-10-25 21:30 | `Parte D: Anonimizacion de datos personales y verificacion de equivalencia` |
| E | `d194e17` | 2026-11-12 | `chore(entrega): consolidar U5, U6 y TP7 del equipo y limpiar duplicados` |

Los mensajes identifican la parte y la acción realizada, y el historial permite
reconstruir el orden del trabajo. La Parte E se consolidó en este mismo archivo
y el commit de cierre completa la secuencia A → E.

La deuda de orden menor quedó saldada: los duplicados de la reorganización y el
texto extraído del PDF se commitearon o se descartaron en `d194e17`. El árbol de
trabajo quedó limpio salvo dos `.zip` de entregas anteriores
(`ENTREGA_TPI/Parcial I_equipoG.zip` y `TP4/tp4.zip`), que no forman parte de
esta entrega.

---

## Unidad 6 — Mantenimiento, respaldo y recuperación

| # | Pedido a la IA (resumen) | Respuesta relevante | Validación / corrección humana |
|---|---|---|---|
| U6-1 | «Redactá la SPEC de mantenimiento y respaldo para `foodStore` con RTO/RPO.» | Propuso `VACUUM FULL` periódico como mantenimiento y no contempló reaplicar privilegios después del restore. | **Rechazado y corregido.** `VACUUM FULL` bloquea y reescribe; se usa `VACUUM (VERBOSE, ANALYZE)` con `n_dead_tup = 0`. El runbook ahora reaplica roles y `GRANT`s tras el restore. |
| U6-2 | «Verificá que la restauración haya quedado bien.» | Informó «restore OK» mirando solo los conteos por tabla. | **Corregido.** Se agregó `has_table_privilege` (detectó `app_web` sin `SELECT` sobre `pedido`) y `validation_drill.sql`: 4/5/12/11/20 filas, 0 inconsistencias. RTO 6,18 s; RPO 6 h 00 m 26 s. |
| U6-3 | «Medí el impacto del incidente y la recuperación.» | Propuso estimar el RPO por la hora del último respaldo sin medirlo. | **Corregido.** Se midió la diferencia real entre el último respaldo y el incidente (`6 h 00 m 26 s`) y se contrastó con la meta (< 24 h). |

## Unidad 7 — NoSQL: migración y evaluación tecnológica

| # | Consigna | Pedido a la IA (resumen) | Respuesta relevante | Validación / corrección humana |
|---|---|---|---|---|
| U7-1 | 1–3 | «Diseñá el modelo documental de pedidos y justificá embedding vs. referencias.» | Recomendó embedding para todo el dominio y afirmó que eliminar JOINs siempre mejora el rendimiento. | **Parcialmente aceptado.** El embedding se adoptó para el documento de pedido (lectura completa en un acceso), pero se refutó la superioridad absoluta: depende del patrón de acceso. Dictamen híbrido. |
| U7-2 | 4 | «Escribí las consultas equivalentes en PostgreSQL a las de MongoDB.» | Generó SQL con `usuario`, `pedido.usuario_id`, `p.total` y `estado = 'TERMINADO'`. | **Detectado en code review.** Ninguno existe en el `schema.sql` publicado (`cliente`, `cliente_id`, total derivable, ENUM sin `TERMINADO`). Se agregó `consultas_postgresql_corregidas.sql` y se documentó la diferencia; el original se conserva como evidencia de lo ejecutado. |
| U7-3 | 5 | «Verificá la paridad entre MongoDB y PostgreSQL.» | Presentó 7/7 y 4/4 como prueba de fidelidad universal. | **Acotado.** La paridad es válida sobre el catálogo de la base de trabajo de U7 (10 pedidos). Sobre el seed publicado los conteos son otros; el informe lo declara. |
| U7-4 | 6–7 | «Refutá las afirmaciones de la IA sobre MongoDB.» | La IA sostuvo que la atomicidad del documento alcanza para el stock y que MongoDB siempre gana en lectura. | **Refutado con documentación oficial.** La atomicidad de documento único no cubre pedido + stock + pago; se requieren transacciones multi-documento. Dictamen: PostgreSQL fuente de verdad, MongoDB almacén de lectura. |

### Caso más significativo (U7: el catálogo que no era)

El error más costoso de U7 no fue conceptual sino de reproducibilidad: la IA
escribió el SQL «equivalente» contra un catálogo que no es el del repositorio.
El script corre en la máquina donde se hizo la práctica, pero un tercero que
clone el repo y cargue `schema.sql` + `seed.sql` obtiene un error de columna, no
una comparación. Se detectó recién al contrastar el SQL con `schema.sql` durante
el code review de cierre. La lección: la paridad entre motores no vale si el
esquema de referencia no está declarado junto al script.

## Unidad 8 — tablet SQLite y semáforo

| # | Parte | Prompt (resumen) | Respuesta relevante de la IA | Validación / corrección humana |
|---|---|---|---|---|
| U8-1 | 1.b | "Diseñá las tablas SQLite con precio y stock." | Proponía `REAL`, sin `STRICT` y sin centavos. | **Corregido.** `precio_centavos INTEGER`, `STRICT`, `CHECK` y `PRAGMA foreign_keys = ON`; se creó la base desde cero y se ejecutaron las pruebas. |
| U8-2 | 2.b | "Escribí el semáforo que compara solicitudes." | Actualizaba todas las solicitudes, incluso las ya aprobadas. | **Corregido.** Solo `PENDIENTE`; `evaluado_en` no cambia al repetir (C6). Evidencia en `movil/evidencias/c6_reevaluacion.txt`. |
| U8-3 | 2.a | "Importá el CSV de psql en SQLite." | Suponía booleanos `0/1`. | **Corregido.** psql exporta `t/f`; se conservan como texto y se normalizan con `CASE`. Verificado en C1 y C4. |
| U8-4 | 2.c | "¿Qué hago cuando el servidor da de baja un producto?" | Borraba la fila de `producto_cache`. | **Descartado.** Se conserva con `eliminado = 1` para no romper la FK y mantener la lápida (C4). |
| U8-5 | 3.c | "Revisá los scripts de la cursada" (OpenCode Plan). | Probó un índice sobre `detalle_pedido(cantidad)` y `VACUUM FULL` periódico. | **Descartados.** El plan sigue `Seq Scan` con y sin índice; `VACUUM FULL` bloquea. Se aceptaron las correcciones de fecha/rango y de ACLs post-restore. Evidencia en `movil/evidencias/code_review_db.txt`. |

### Caso más significativo (U8: la tablet no debe borrar la lápida)

En **U8-4** la IA propuso eliminar la fila local del producto dado de baja. Eso
rompe la FK de `item_borrador` y borra la prueba del motivo del rechazo. Se
corrigió a una baja lógica local (`eliminado = 1`, `disponible = 0`): el
catálogo disponible ya no la muestra, pero la fila queda para C4. La lección es
que la caché también necesita una política de bajas, no solo de altas.

## Estado de Git

| Unidad | Commits |
|---|---|
| U4 | `b2bde0d`, `aa59180` |
| U5 | `19690c9`, `3aa729d`, `aeb97dc`, `aab0868`, `bc97b80`, cierre `d194e17` |
| U6 | `4e02112`, consolidación `d194e17` |
| U7 | `f517c98`, consolidación `d194e17` |
| U8 | `4b97f27`, `c6837c7`, `46a6634`, `507d798` |

La U5 quedó con la versión del equipo (Partes A–E, rama de Julieta) y la U6 con
la de Ivana en `TP6/`. Las variantes locales de U5 y U6 se descartaron para no
duplicar implementaciones. El TP7 quedó consolidado en
`Trabajo Practico - Unidad 7/`, con el informe que incluye a todo el equipo y
con el código de la migración y las consultas.

El cierre de la segunda entrega (informe único, checklist, code review, specs de
U4 y consolidación de esta bitácora) es el commit que agrega
`SEGUNDA_ENTREGA/`; se lo puede ubicar con
`git log --oneline -- SEGUNDA_ENTREGA docs/kiro_u4`.
