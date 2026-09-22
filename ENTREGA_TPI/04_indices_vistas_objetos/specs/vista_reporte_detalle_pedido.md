# spec: vista v_reporte_detalle_pedido

**Objetivo:** simplificar "detalle de un pedido con el nombre del producto" —
la consulta de factura/consulta de línea que usa el vendedor.

**Vista a generar con OpenCode:** por cada línea de detalle, sumar el
`nombre` del producto y un **importe derivado** `cantidad * precio_unitario`
(regla R4: montos siempre NUMERIC derivados, nunca almacenados).

**Columnas a exponer:** `linea_id` (detalle_pedido.id), `pedido_id`, `fecha`
(del pedido, para filtrar por periodo), `producto_id`, `producto` (nombre),
`cantidad`, `precio_unitario`, `importe`.

**Qué ocultar:** los `created_at` y la `descripcion` (largo, innecesario en
el detalle operativo).

**Criterio de aceptación:** la vista coincide EXACTO (EXCEPT 0/0) con la
consulta manual equivalente (JOIN detalle × pedido × producto con las mismas
columnas y el mismo `importe` derivado).