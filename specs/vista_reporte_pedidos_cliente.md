# spec: vista v_reporte_pedidos_cliente

**Objetivo:** simplificar "pedidos con los datos del cliente" (panel de
seguimiento, mesa de ayuda).

**Vista a generar con OpenCode:** reunir en una sola lista los pedidos con
los datos del cliente que los realizó.

**Columnas a exponer:** `pedido_id`, `fecha`, `estado`, `forma_pago` (del
pedido) y `cliente_id`, `nombre`, `apellido`, `email` (del cliente).

**Filtros:** la vista expone TODOS los pedidos (el estado se filtra en la
consulta; la vista estandariza la lectura, no decide el negocio). Sin filtro
de fecha: el panel elige el rango.

**Qué ocultar por seguridad / privacidad:** los `created_at` de pedido y
cliente, y el `telefono` del cliente (dato personal): la vista de contacto
seguro es la spec `v_cliente_contacto`, no esta. Esperanza de diseño: el
`telefono` NO sale por esta vista.

**Criterio de aceptación:** la vista coincide EXACTO (EXCEPT 0/0) con la
consulta manual equivalente (JOIN pedido × cliente con las mismas columnas).