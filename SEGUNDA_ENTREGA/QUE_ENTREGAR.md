# Qué entregar — TPI Food Store (Segunda entrega, Unidades 4 a 8)

**Materia:** Base de Datos II — UTN FRM · **Equipo G** (Ivana Gutiérrez, Rayssa Alejo, Julieta Chávez, Brisa Muñoz)  
**Commit de referencia:** `71a38b3` (`main`)

Esta carpeta (`SEGUNDA_ENTREGA/`) reúne **todo lo que se debe entregar** para la segunda entrega: documentos de cierre, scripts, specs, evidencias e informes de las Unidades 4 a 8.

## 1. Documentos obligatorios de cierre (entregar sí o sí)

| # | Documento | Archivo |
|---|---|---|
| 1 | **Informe técnico único** (U4–U8): implementación, pruebas, resultados, decisiones, herramientas/prompts/specs de IA aceptados/descartados | `informe_tecnico_segunda_entrega.pdf` (y `.md`) |
| 2 | **Checklist de objetivos** (14) con evidencia y verificación | `checklist_segunda_entrega.md` |
| 3 | **Code review final asistido por IA** de todos los scripts, con decisión humana por hallazgo | `code_review_segunda_entrega.md` |
| 4 | **DUIA** (Declaración de Uso de IA) | `../docs/DUIA.md` *(también referenciada desde el informe y el README)* |
| 5 | **Bitácora de IA** (prompts/specs, respuestas, aceptaciones/descartes y correcciones) | `../BITACORA.md` |
| 6 | **Índice / guía de la entrega** | `README_ENTREGA.md` |

> Los ítems 4 y 5 se mantienen en la raíz del repositorio (`docs/DUIA.md`, `BITACORA.md`) para no duplicarlos; el informe y este índice los enlazan. Si la cátedra exige un paquete autocontenido, incluir también esas dos copias.

## 2. Entregables por unidad (carpetas U4–U8)

### Unidad 4 — Normalización avanzada y redundancia (`U4/`)
- `tp_fnbc_control_lote.sql` — refactorización a FNBC, anomalías (SAVEPOINT/ROLLBACK), migración en transacción, verificación de reunión sin pérdida y contraejemplo (F-U4-4), vista de compatibilidad.
- `tp_desnormalizacion_top_categorias.sql` — cubo `fact_venta_categoria_dia`, disparadores de sincronización (caliente/frío), backfill, auditoría y equivalencia.
- `carga_dia_actual.sql` — siembra del día para medir el `EXPLAIN ANALYZE`.
- `TP6_Food_Store.pdf` (e `informe_tp6.md`, `generar_pdf_tp6.py`) — informe con planes antes/después, justificación y desnormalización controlada documentada.
- `kiro_u4/` — specs (`requirements.md`, `design.md`, `tasks.md`) con **plan de reversión** obligatorio.

### Unidad 5 — Administración y seguridad (`U5/`)
- `roles.sql` — esquema de usuarios, roles y permisos (mínimo privilegio, permiso por columna, `ALTER DEFAULT PRIVILEGES`).
- `simulacro_incidente.sql`, `usuario_anon.sql`.
- `informe_auditoria.md`, `informe_incidente.md`, `verificacion_permisos.txt`, `verificacion_equivalencia.md` y logs (`log_auditoria_prueba.txt`, `log_simulacro_anonimizado.txt`, `log_simulacro_crudo.txt`, `respuesta_opencode_incidente.txt`).
- `kiro_roles_spec/` — specs de Kiro y auditoría de seguridad asistida por IA con decisión humana.

### Unidad 6 — Mantenimiento (`U6/`)
- `SPEC_U6.md` — plan de mantenimiento (respaldo programado, restauración, tareas rutinarias) y programación automatizada.
- `backup_foodstore.ps1`, `schedule_u6.ps1` (tareas diarias/semanales en Windows), `restore_test.ps1`.
- `sql/health_check.sql`, `sql/maintenance.sql`, `sql/validation_drill.sql`.
- `informe_u6.pdf` (`.md`) y `anexo_evidencias_u6.pdf` — simulacro de desastre, **RTO 6,18 s** y **RPO 6 h 00 m 26 s**, informe post-incidente.

### Unidad 7 — NoSQL (`U7/`)
- `migracion_mongodb.js` — modelado documental (embedding), validador e índices.
- `consultas_mongodb.js`, `consultas_postgresql.sql` (ejecutado) y `consultas_postgresql_corregidas.sql` (catálogo real de `schema.sql`).
- `informe_tp7.pdf` (`.md/.html`, `BDII_Unidad7_TP_FoodStore_NoSQL.pdf`) — comparación práctica relacional/documental y justificación de la tecnología.

### Unidad 8 — Móvil e integración (`U8/`)
- `movil/schema_sqlite.sql`, `semaforo.sql`, `pruebas_sqlite.sql`, `v_snapshot_movil.sql`, `exportar_snapshot.sql`, `verificacion_servidor.sql`, `servidor_snapshot.csv`, `foodstore_movil.db`, `evidencias/` — esquema SQLite, sincronización simulada, casos de conflicto y resolución.
- `kiro/` — specs de Kiro (esquema y sincronización).
- `informe.pdf`, `informe_u8.md`, `generar_informe_u8.py`, `bitacora_ia.md`.

## 3. Cobertura de los objetivos de la consigna

Los 14 objetivos de U4–U8, con su evidencia y forma de verificación, están trazados en `checklist_segunda_entrega.md`. El `code_review_segunda_entrega.md` registra la revisión asistida por IA y la decisión humana sobre cada hallazgo.

## 4. Nota pendiente (verificada pero por reejecutar en motor)

- **U4 (F-U4-4):** la corrección sin pérdida está aplicada y su lógica fue validada por simulación, pero **falta reejecutarla en PostgreSQL** para refrescar la salida verificada. Ejecutar `U4/tp_fnbc_control_lote.sql` sobre `food_store_tp6` (`psql -v ON_ERROR_STOP=1 -f ...`) y comprobar `EXCEPT` 0/0, conteos/firma y contraejemplo 4 vs 2.
- **U6:** para que el respaldo quede efectivamente programado, registrar las tareas con `U6/schedule_u6.ps1` en un PowerShell como Administrador (requiere `pgpass.conf`).

## 5. Protocolo de IA (respetado)

Ningún script generado por IA se incorporó sin lectura, comprensión y prueba; no se enviaron datos personales/sensibles a la IA; todo uso está declarado en la DUIA y la bitácora; el equipo puede explicar cada decisión en la defensa.
