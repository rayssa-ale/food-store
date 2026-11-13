# Declaracion de Uso de IA (DUIA) - Unidad 8

**Materia:** Base de Datos II - UTN FRM
**Proyecto:** Food Store
**Entrega:** TP8 - Food Store en la feria
**Integrantes:** Ivana Gutierrez, Rayssa Alejo, Julieta Chavez, Brisa Munoz
**Fecha:** Noviembre de 2026

## Herramientas y alcance

- **Kiro:** se usaron `docs/kiro/requirements.md`, `design.md` y `tasks.md` para
  definir el esquema SQLite y el semaforo antes de generar codigo.
- **OpenCode:** generacion y revision de `schema_sqlite.sql`, `semaforo.sql`,
  `pruebas_sqlite.sql` y los scripts de evidencia. En el code review se uso el
  agente Plan para revisar scripts de unidades anteriores.
- **PostgreSQL 18.6 / SQLite 3.50.4:** motores que validaron cada propuesta.

## Datos y privacidad

No se envio a la IA ningun mail, telefono, nombre real, hash de contrasena ni
fila completa de clientes. La instantanea que viaja a la tablet contiene solo
`producto_id`, nombre de producto, precio en centavos, stock visto, disponible,
eliminado y fecha de copia. Los borradores usan el alias local
`vendedor_feria`; no se usan datos personales reales.

## Reglas respetadas

1. Se trabajo sobre la copia `foodstore_u8`, creada desde `foodstore`.
2. La tablet **nunca** escribe en PostgreSQL: `SIMULADO_APROBADO` no es una
   venta. La verificacion `movil/verificacion_servidor.sql` muestra que pedidos,
   lineas, productos y stock no cambiaron.
3. Cada sugerencia de la IA se leyo y se ejecuto antes de incorporarla.
4. Los hallazgos del code review tienen decision y comprobacion en
   `movil/evidencias/code_review_db.txt`; el indice descartado se justifica con
   el plan real (`Seq Scan`).
5. La bitacora completa, con prompts, aceptaciones y descartes, esta en
   `docs/bitacora_ia.md`.

## Archivos generados con asistencia de IA

- `movil/schema_sqlite.sql`
- `movil/semaforo.sql`
- `movil/pruebas_sqlite.sql`
- `movil/v_snapshot_movil.sql`
- `movil/verificacion_servidor.sql`
- `docs/informe.pdf` (a partir de `docs/informe_u8.md`)

Todos fueron revisados, ejecutados y contrastados contra el motor. Lo que no se
puede explicar en la defensa se considera no realizado.
