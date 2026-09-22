# spec: vista v_cliente_contacto (seguridad)

**Objetivo:** exponer la información de contacto de los clientes **sin**
datos personales no imprescindibles, de modo que se pueda otorgar `SELECT`
sobre la vista sin dar acceso a la tabla base `cliente`.

**Contexto de adaptación (documentado para la defensa):** el enunciado pide
"exponer usuario sin la columna contraseña". El modelo local de Food Store no
tiene tabla `usuario` ni columna `contraseña` (el alta es `cliente` con
`email` único, ver `schema.sql` / R6). El dato personal más sensible que
almacena `cliente` es el `telefono`; aplicar el mismo criterio de seguridad
de la teoría (mínima exposición) significa **no** exponer `telefono` ni el
`created_at` interno.

**Vista a generar con OpenCode:** 

```sql
CREATE VIEW v_cliente_contacto AS
SELECT c.id, c.nombre, c.apellido, c.email
FROM cliente c;
```

**Administración de permisos (en el spec y en la bitácora):** tras crear la
vista se debe `REVOKE SELECT ON cliente FROM public` y
`GRANT SELECT ON v_cliente_contacto TO public` (en producción, solo a
`rol_ventas`). Así nadie con solo `SELECT` sobre la vista alcanza `telefono`.

**Criterio de aceptación:** la vista coincide EXACTO (EXCEPT 0/0) con la
consulta manual equivalente (misma SELECT sin `telefono`), y el `telefono`
no está entre las columnas de la vista (se comprueba con `information_schema.columns`).