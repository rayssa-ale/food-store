# Segunda entrega del TPI — Food Store (Unidades 4 a 8)

**Materia:** Base de Datos II — UTN FRM · **Equipo G**  
**Integrantes:** Ivana Gutiérrez, Rayssa Alejo, Julieta Chávez, Brisa Muñoz  
**Fecha:** noviembre de 2026 · **Rama:** `main` · **Commit:** `71a38b3`

Esta carpeta reúne **la entrega completa de la segunda instancia**: documentos de cierre y, en las carpetas `U4/`–`U8/`, los artefactos de cada unidad (scripts, specs, informes y evidencias).

> **Para saber exactamente qué entregar, ver `QUE_ENTREGAR.md`.**

## Contenido de la carpeta

| Elemento | Qué contiene |
|---|---|
| `QUE_ENTREGAR.md` | Lista concreta de lo que debe entregarse |
| `informe_tecnico_segunda_entrega.md` / `.pdf` | Informe técnico único U4–U8 (resultados, pruebas, decisiones, uso de IA) |
| `checklist_segunda_entrega.md` | 14 objetivos con evidencia y forma de verificación |
| `code_review_segunda_entrega.md` | Revisión asistida por IA de todos los scripts y decisión humana por hallazgo |
| `U4/` … `U8/` | Entregables de cada unidad (scripts, informes/PDF, specs Kiro y evidencias) |
| `generar_informe_segunda_entrega.py` | Regenera el PDF del informe consolidado |

**Fuera de esta carpeta (referenciados, no duplicados):** `../docs/DUIA.md` (DUIA) y `../BITACORA.md` (bitácora de IA).

## Orden de lectura sugerido

1. `QUE_ENTREGAR.md` — qué hay que entregar.
2. `informe_tecnico_segunda_entrega.md` §1 — resumen ejecutivo.
3. `checklist_segunda_entrega.md` — objetivos y evidencia.
4. Carpeta de la unidad que interese (`U4/`…`U8/`).
5. `code_review_segunda_entrega.md` — correcciones y deuda documentada.
6. `../docs/DUIA.md` y `../BITACORA.md` — uso de IA y correcciones humanas.

## Verificación rápida

```powershell
# Repositorio
git status --short

# U4 (corre FNBC + cubo sobre la copia)
$psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'
& $psql -d food_store_tp6 -v ON_ERROR_STOP=1 -f SEGUNDA_ENTREGA/U4/tp_fnbc_control_lote.sql
& $psql -d food_store_tp6 -v ON_ERROR_STOP=1 -f SEGUNDA_ENTREGA/U4/tp_desnormalizacion_top_categorias.sql

# U8: la tablet no escribió en el servidor
& $psql -d foodstore_u8 -f SEGUNDA_ENTREGA/U8/movil/verificacion_servidor.sql
```

## Nota sobre cifras y pendientes

- Las métricas de volumen (549.529 filas en `detalle_pedido`, 227.009 pedidos, 50.006 productos) corresponden a las bases de trabajo; con `seed.sql` cambian los conteos, no la semántica.
- **U4 (F-U4-4):** la descomposición sin pérdida está corregida y validada por simulación; falta reejecutarla en el motor para refrescar la salida verificada.
- **U7:** se conserva el SQL original (catálogo de trabajo) y se incluye el corregido para `schema.sql`.
- **U5/U6:** auditoría nativa (no `pgaudit`), RPO atado a respaldo diario (sin PITR); la programación de U6 se registra con `U6/schedule_u6.ps1`.
