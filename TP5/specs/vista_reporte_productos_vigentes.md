# spec: vista v_reporte_productos_vigentes

**Objetivo:** simplificar el reporte habitual "carta vigente con su rubro".

**Vista a generar con OpenCode:** mostrar cada producto vigente con los datos
de su categoría, de modo que los reportes no repitan el JOIN ni el filtro de
vigencia.

**Columnas a exponer:** `id` (producto), `nombre` (producto), `descripcion`,
`precio`, `stock`, `categoria` (nombre de la categoría).

**Filtros:** producto vigente (`p.activo = TRUE`) **y** categoría vigente
(`c.activo = TRUE`).

**Qué ocultar por seguridad:** nada sensible en esta vista; sí el
`created_at` de ambas tablas (no aporta al reporte y no se quiere exponer el
alta interna).

**Criterio de aceptación:** la vista responde con las 50.006 filas vigentes
y coincide EXACTO (EXCEPT 0/0) con la consulta manual equivalente escrita por
el estudiante.

**Nota:** verificar también que la vista sea solo de lectura por diseño (no
lleva RLS ni triggers INSTEAD OF): su uso es reutilización y estándar de
lectura.