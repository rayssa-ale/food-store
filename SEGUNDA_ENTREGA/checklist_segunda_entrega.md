# Checklist de la segunda entrega — Unidades 4 a 8

**Proyecto:** Food Store · **Equipo G** · **Materia:** Base de Datos II (UTN FRM)
**Estado:** completo con observaciones (ver §5) · **Fecha:** noviembre de 2026

Cada objetivo se considera cumplido solo si tiene **evidencia ejecutada** en el
repositorio y una forma de verificarlo. La columna «Verificación» indica el
archivo o comando que permite contrastarlo sin confiar en este documento.

## 1. Objetivos técnicos (14)

| # | Unidad | Objetivo | Evidencia | Verificación |
|---|---|---|---|---|
| 1 | U4 | Analizar `control_lote_almacen` contra FNBC: DFs, clausuras, claves candidatas y distinción con 3FN | `TP6/tp_fnbc_control_lote.sql` §(a)–(c) | Ejecutar el script; el bloque de comentarios enumera K1 y K2 y dictamina la violación de FD2 |
| 2 | U4 | Descomponer en FNBC, demostrar las tres anomalías y auditar la reunión | `TP6/tp_fnbc_control_lote.sql` §(d)–(f) | `EXCEPT` 0/0, cardinalidad/firma y prueba inyectiva; contraejemplo F-U4-4 (4 filas vs. 2) incluido. **Pendiente reejecutar** en el motor para refrescar la salida verificada. |
| 3 | U4 | Desnormalizar el top 5 con justificación medida, camino caliente/frío y equivalencia | `TP6/tp_desnormalizacion_top_categorias.sql`; `TP6/TP6_Food_Store.pdf` | `EXPLAIN ANALYZE` antes (`549.529` filas, `138,0 ms`) y después (`3` filas, `6` buffers, `0,118 ms`); `EXCEPT` 0/0 |
| 4 | U5 | Diseñar roles y permisos con mínimo privilegio, permiso por columna y `ALTER DEFAULT PRIVILEGES` | `sql/roles.sql`; `docs/kiro_roles_spec/` | `\du` y `information_schema.role_table_grants` en `docs/verificacion_permisos.txt`; `pg_default_acl` en 0 filas |
| 5 | U5 | Activar la auditoría nativa y conservar la evidencia del log | `sql/roles.sql` (config), `docs/log_auditoria_prueba.txt`, `docs/informe_auditoria.md` | `SHOW log_statement` y hash SHA-256 del fragmento (`9C2C3C…6C93`) |
| 6 | U5 | Ejecutar el simulacro de incidente y analizarlo de forma forense, contrastando la IA con el log crudo | `sql/simulacro_incidente.sql`, `docs/informe_incidente.md`, `docs/respuesta_opencode_incidente.txt` | Cronología reconstruida solo con el log anonimizado y luego contrastada con `docs/log_simulacro_crudo.txt` |
| 7 | U5 | Anonimizar datos personales y verificar la equivalencia analítica sin fuga | `sql/usuario_anon.sql`, `docs/verificacion_equivalencia.md` | 20.000 filas; `EXCEPT` 0/0; 0 coincidencias en PII; md5 `703bd7ed…90eb` estable |
| 8 | U6 | Definir y ejecutar la política de respaldo | `TP6/backup_foodstore.ps1`, `TP6/SPEC_U6.md` | `foodStore_2026-10-30_172759.dump` (32,62 KB) y `pg_restore --list` |
| 9 | U6 | Probar la restauración y medir RTO/RPO con validación de integridad | `TP6/restore_test.ps1`, `TP6/sql/validation_drill.sql`, `TP6/informe_u6.md` | RTO 6,18 s; RPO 6 h 00 m 26 s; 4/5/12/11/20 filas; 0 inconsistencias |
| 10 | U6 | Monitorear y mantener sin bloquear: health check y `VACUUM ANALYZE` | `TP6/sql/health_check.sql`, `TP6/sql/maintenance.sql` | `n_dead_tup = 0`; política explícita anti-`VACUUM FULL` |
| 11 | U7 | Diseñar y ejecutar la migración documental con embedding, validador e índices | `Trabajo Practico - Unidad 7/informe_tp7.md` §2.1–§2.3; `migracion_mongodb.js` | `insertMany` de 10 documentos; 5 índices; `$jsonSchema` con ENUM; embedding justificado frente a referencias |
| 12 | U7 | Ejecutar consultas cruzadas y verificar paridad | `consultas_mongodb.js`, `consultas_postgresql.sql` | 7/7 en `estado` y 4/4 en producto, con los mismos IDs |
| 13 | U7 | Evaluar tecnológicamente y emitir dictamen de arquitectura | `informe_tp7.md` §4 | Refutación documentada y dictamen híbrido (172 palabras) |
| 14 | U8 | Implementar la tablet SQLite y el semáforo con pruebas C1–C7 y garantía de no escritura | `movil/schema_sqlite.sql`, `movil/semaforo.sql`, `movil/pruebas_sqlite.sql`, `movil/evidencias/` | `integrity_check = ok`; 50.006 productos; 6 solicitudes; `verificacion_servidor.sql` sin cambios |

## 2. Condiciones formales de la entrega

| Requisito formal | Archivo | Estado |
|---|---|---|
| Informe técnico único | `SEGUNDA_ENTREGA/informe_tecnico_segunda_entrega.md` + `.pdf` | Completo |
| Declaración de uso de IA (DUIA) | `docs/DUIA.md` | Completo (U4–U8) |
| Bitácora de IA con prompts, respuestas y correcciones | `BITACORA.md` | Completo (U4–U8) |
| Especificaciones de Kiro | `docs/kiro_u4/`, `docs/kiro_roles_spec/`, `docs/kiro/` | Completo |
| Code review de los scripts | `SEGUNDA_ENTREGA/code_review_segunda_entrega.md` | Completo |
| Checklist de objetivos | Este archivo | Completo |
| Repositorio sin binarios ni respaldos versionados | `.gitignore` (`backups/`, `logs/`) | Completo |
| Historial de commits por unidad | `git log --oneline` | Completo |

## 3. Evidencia por unidad (mapa rápido)

| Unidad | Scripts | Informe | Evidencias |
|---|---|---|---|
| U4 | `TP6/tp_fnbc_control_lote.sql`, `TP6/tp_desnormalizacion_top_categorias.sql` | `TP6/TP6_Food_Store.pdf` | Planes y `EXCEPT` dentro de los scripts |
| U5 | `sql/roles.sql`, `sql/simulacro_incidente.sql`, `sql/usuario_anon.sql` | `docs/informe_auditoria.md`, `docs/informe_incidente.md` | `docs/log_auditoria_prueba.txt`, `docs/log_simulacro_*.txt`, `docs/verificacion_permisos.txt`, `docs/verificacion_equivalencia.md` |
| U6 | `TP6/backup_foodstore.ps1`, `TP6/restore_test.ps1`, `TP6/sql/*.sql` | `TP6/informe_u6.pdf`, `TP6/SPEC_U6.md` | `TP6/anexo_evidencias_u6.pdf` |
| U7 | `Trabajo Practico - Unidad 7/*.js`, `*.sql` | `Trabajo Practico - Unidad 7/informe_tp7.pdf` | Salidas en el informe; `code_review_segunda_entrega.md` |
| U8 | `movil/*.sql` | `docs/informe.pdf`, `docs/informe_u8.md` | `movil/evidencias/casos_c1_c7.txt`, `movil/evidencias/*` |

## 4. Verificación mínima antes de entregar

```powershell
# 1. El repositorio no tiene cambios sin commitear
git status --short

# 2. Los scripts de U4 corren de punta a punta sobre la copia
$psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'
& $psql -d food_store_tp6 -v ON_ERROR_STOP=1 -f TP6/tp_fnbc_control_lote.sql
& $psql -d food_store_tp6 -v ON_ERROR_STOP=1 -f TP6/tp_desnormalizacion_top_categorias.sql

# 3. La tablet no escribió en el servidor
& $psql -d foodstore_u8 -f movil/verificacion_servidor.sql
```

## 5. Observaciones de cierre

| ID | Unidad | Observación | Estado |
|---|---|---|---|
| F-U4-4 | U4 | La descomposición `(Resp, Dep) + (Lote, Dep)` era con pérdida; se corrigió a `control_lote(lote_id, responsable_control_id)` con contraejemplo y costo de preservación declarado | **Corregido** (pendiente reejecutar en el motor) |
| F-U7-1 | U7 | El SQL original usa un catálogo (`usuario`, `total`, `TERMINADO`) distinto del `schema.sql` publicado | Script corregido + nota en el informe |
| F-U7-3 | U7 | El seed de la migración incluye contactos con formato real | Deuda: reemplazar por `@example.test` |

Las tres están documentadas con su evidencia en
`SEGUNDA_ENTREGA/code_review_segunda_entrega.md`. F-U4-4 no bloquea la entrega
como diseño: el artefacto corregido está incorporado; resta refrescar la salida
ejecutada.

## 6. Declaración

Todo lo listado fue ejecutado y revisado por el equipo. Lo que no se pueda
explicar en la defensa se considera no realizado, con independencia de que el
archivo exista.
