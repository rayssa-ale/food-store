# Segunda entrega del TPI — Food Store (Unidades 4 a 8)

**Materia:** Base de Datos II — UTN FRM · **Equipo G**
**Integrantes:** Ivana Gutiérrez, Rayssa Alejo, Julieta Chávez, Brisa Muñoz
**Fecha:** noviembre de 2026 · **Rama:** `main`

Este directorio reúne los documentos de cierre de la segunda entrega. Los
artefactos técnicos (scripts, informes de laboratorio y evidencias) siguen en
las carpetas de cada unidad; acá está el documento único que los integra y los
controles formales que pidió la cátedra.

## Qué se entrega

| Documento | Archivo | Para qué sirve |
|---|---|---|
| Informe técnico único | `informe_tecnico_segunda_entrega.md` / `.pdf` | Recorre U4–U8 con resultados verificables y condiciones de reproducción |
| Checklist de objetivos | `checklist_segunda_entrega.md` | Los 14 objetivos con su evidencia y cómo verificarlos |
| Code review | `code_review_segunda_entrega.md` | Hallazgos, severidad y decisión sobre todos los scripts |
| DUIA | `../docs/DUIA.md` | Declaración de uso de IA de U4–U8 |
| Bitácora de IA | `../BITACORA.md` | Prompts, propuestas, correcciones y descartes |
| Specs de Kiro | `../docs/kiro_u4/`, `../docs/kiro_roles_spec/`, `../docs/kiro/` | Requisitos, diseño y tareas antes del código |

## Orden de lectura sugerido

1. `informe_tecnico_segunda_entrega.md` §1 — resumen ejecutivo en una tabla.
2. `checklist_segunda_entrega.md` — qué se pidió y dónde está la evidencia.
3. La unidad que interese del informe (§3 a §7).
4. `code_review_segunda_entrega.md` — qué se corrigió y qué queda como deuda.
5. `../docs/DUIA.md` y `../BITACORA.md` — cómo se usó la IA y qué se rechazó.

## Evidencia por unidad

| Unidad | Carpeta | Qué mirar primero |
|---|---|---|
| U4 — FNBC y desnormalización | `../TP6/` | `TP6_Food_Store.pdf`, los dos `.sql` |
| U5 — Seguridad y anonimización | `../sql/`, `../docs/` | `roles.sql`, `informe_auditoria.md`, `informe_incidente.md`, `verificacion_equivalencia.md` |
| U6 — Respaldo y recuperación | `../TP6/`, `../TP6/sql/` | `SPEC_U6.md`, `informe_u6.pdf`, `anexo_evidencias_u6.pdf` |
| U7 — NoSQL | `../Trabajo Practico - Unidad 7/` | `informe_tp7.pdf`, `migracion_mongodb.js`, `consultas_mongodb.js` |
| U8 — Tablet y semáforo | `../movil/`, `../docs/` | `informe.pdf`, `evidencias/casos_c1_c7.txt` |

## Verificación rápida

```powershell
# Repositorio limpio
git status --short

# U4 corre de punta a punta sobre la copia
$psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'
& $psql -d food_store_tp6 -v ON_ERROR_STOP=1 -f TP6/tp_fnbc_control_lote.sql
& $psql -d food_store_tp6 -v ON_ERROR_STOP=1 -f TP6/tp_desnormalizacion_top_categorias.sql

# U8: la tablet no escribió en el servidor
& $psql -d foodstore_u8 -f movil/verificacion_servidor.sql
```

## Nota sobre cifras

Las mediciones de volumen (549.529 filas en `detalle_pedido`, 227.009 pedidos,
50.006 productos) corresponden a las bases de trabajo de cada unidad. Reproducir
desde `seed.sql` da el conjunto mínimo (3 pedidos, 6 productos): los planes y la
semántica se mantienen, los conteos no son comparables. Cada informe lo aclara
en su sección de condiciones.

## Limitaciones declaradas

- U4: F-U4-4 (descomposición con pérdida) fue corregido en el script y en el
  informe; la salida verificada en el motor quedó pendiente de reejecución (no
  se dispuso de contraseña en la sesión de cierre). La lógica fue validada con
  una simulación paso a paso y el contraejemplo está incorporado.
- U7: el SQL original usa un catálogo (`usuario`, `total`, `TERMINADO`) distinto
  del `schema.sql` publicado; se agrega una versión corregida y se documenta.
- U5: la auditoría es nativa (por sentencia), no fila por fila como `pgaudit`.
- U5: la anonimización es un reemplazo determinista con equivalencia agregada,
  no k-anonimidad.
- U6: el RPO depende de la frecuencia de respaldo (diaria), no de PITR.
