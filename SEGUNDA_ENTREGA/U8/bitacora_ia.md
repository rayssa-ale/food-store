# Bitacora de uso de IA - Unidad 8 (TP8)

**Herramientas:** Kiro (requirements/design/tasks) y OpenCode (generacion y
revision de SQL, agente Plan para el code review). **Regla aplicada:** la IA
propone, el motor y los numeros deciden; todo se leyo y se ejecuto antes de
incorporarlo.

| # | Pedido a la IA | Que propuso | Decision humana y comprobacion |
|---|---|---|---|
| U8-1 | "Disena las tablas SQLite de la tablet con precio y stock." | Un esquema con `precio REAL`, sin `STRICT` y sin centavos. | **Corregido.** Se paso a `precio_centavos INTEGER`, tablas `STRICT`, `CHECK` de no negativos y `PRAGMA foreign_keys = ON`. Se comprobo creando la base desde cero y ejecutando `pruebas_sqlite.sql`. |
| U8-2 | "Escribe el semaforo que compara solicitudes con la instantanea." | Actualizaba todas las solicitudes, incluidas las ya aprobadas. | **Corregido.** Se limito a `estado = 'PENDIENTE'` para que repetir la simulacion no reevalue (C6). Verificado con `evaluado_en` sin cambios en `movil/evidencias/c6_reevaluacion.txt`. |
| U8-3 | "Importa el CSV de psql en SQLite." | Suponia booleanos `0/1` en el CSV. | **Corregido.** psql exporta `t/f`; se conservaron como texto en `snapshot_servidor` y se normalizaron con `CASE` al cargar `producto_cache`. Se comprobo con el catalogo C1 y con C4. |
| U8-4 | "Que hago cuando el servidor da de baja un producto?" | Borraba la fila de `producto_cache`. | **Descartado.** Borrarla rompe la FK del borrador y oculta el motivo. Se conserva la fila con `eliminado = 1` y `disponible = 0` (C4); el catalogo disponible la excluye. Verificado con la consulta de cache y la de catalogo. |
| U8-5 | "Revisa los scripts de la cursada y propone mejoras" (agente Plan). | Probo un indice sobre `detalle_pedido(cantidad)` y un `VACUUM FULL` periodico. | **Descartados.** El indice no cambia el plan de agregacion (sigue `Seq Scan`; ver `movil/evidencias/code_review_db.txt`). `VACUUM FULL` bloquea y reescribe; se mantiene `ANALYZE`. Se aceptaron las correcciones de fecha/rango y de privilegios post-restore. |

## Hallazgos del code review usados en el informe

1. **U6 - restore y ACLs.** `pg_restore --no-owner --no-privileges` deja los
   datos, pero `app_web` no puede leer `pedido` en `foodstore_restore_test`
   (`has_table_privilege = f`). Decision: **corregido** en el runbook,
   reaplicando roles/grants despues del restore.
2. **U4/TP6 - filtro de fecha.** `fecha = CURRENT_DATE` devuelve 0 filas;
   `fecha >= CURRENT_DATE AND fecha < CURRENT_DATE + 1` devuelve 1 en la copia.
   Decision: **corregido** con predicado de rango.
3. **U5 - privilegios por defecto.** `pg_default_acl` quedo vacio y
   `rol_reportes` no puede leer la vista con PII. Decision: **corregido** con
   *default deny* y otorgamiento explicito.
4. **U5/TP5 - indice descartado.** `detalle_pedido(cantidad)` no elimina el
   `Seq Scan` de la agregacion. Decision: **descartado** con fundamento.

## Declaracion

No se enviaron a la IA mails, telefonos, nombres reales, contrasenas ni filas
completas de clientes. El unico dato que viaja a la tablet es el catalogo de
productos y un alias local (`vendedor_feria`). La declaracion formal esta en
`docs/DUIA.md`.
