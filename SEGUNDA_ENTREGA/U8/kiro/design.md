# Kiro - Design - Unidad 8
## Esquema SQLite y semaforo de sincronizacion

**Motores:** PostgreSQL 18.6 (servidor de pruebas `foodstore_u8`) y SQLite
3.50.4 (archivo `movil/foodstore_movil.db`). **Regla de oro:** el movil propone,
el servidor dispone.

## 1. Modelo de la tablet

| Tabla | Rol | Decisiones |
|---|---|---|
| `producto_cache` | Catalogo local | Precio en **centavos** (`INTEGER`), `disponible` y `eliminado` como `0/1`, `fecha_copia` para saber que instantanea se uso. |
| `pedido_borrador` | Cabecera del borrador | `id_local` UUID, `usuario` es un alias local (sin PII), `forma_pago` cerrada por `CHECK`. |
| `item_borrador` | Lineas | FK a borrador y a cache, `cantidad > 0`, `precio_centavos_visto` congelado. |
| `cola_sync` | Solicitudes | `solicitud_uuid` PK, estado cerrado por `CHECK`, `motivo` y `evaluado_en`. |
| `snapshot_servidor` | Apoyo de importacion | Conserva `t/f` del CSV de psql; no es parte del modelo operativo. |

Todas las tablas son `STRICT` y se crean con `PRAGMA foreign_keys = ON;`.

## 2. Instantanea del servidor

`v_snapshot_movil` expone solo datos de catalogo:

`producto_id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia`

`disponible = p.activo AND c.activo`; `eliminado = NOT p.activo`. La vista se
exporta con `\copy ... CSV HEADER`. psql escribe los booleanos como `t/f`, y
`semaforo.sql` los normaliza a `0/1` al cargar `producto_cache`.

## 3. Carga y semaforo

1. `DELETE FROM snapshot_servidor` antes de importar la nueva instantanea.
2. `INSERT ... ON CONFLICT (id) DO UPDATE` actualiza `producto_cache`; una baja
   logica **no borra** la fila, la marca `eliminado = 1` (C4).
3. Se evaluan solo `cola_sync.estado = 'PENDIENTE'`:
   - `RECHAZADO` si falta el producto, esta eliminado/no disponible o no alcanza
     el stock.
   - `CONFLICTO` si no hay rechazo pero cambio un precio.
   - `SIMULADO_APROBADO` si todo coincide.
4. Se guardan `estado`, `motivo` y `evaluado_en`. Repetir la corrida no cambia
   solicitudes ya evaluadas (C6).

## 4. Seguridad e integridad

- SQLite no tiene usuario de servidor ni conexion a PostgreSQL en esta practica:
  la simulacion termina en `SIMULADO_APROBADO`, que **no es una venta**.
- No viajan mails, telefonos, hashes ni historial de pedidos. El alias
  `vendedor_feria` es local.
- `CHECK`, `FK` y `STRICT` impiden precios negativos, cantidades no positivas,
  estados fuera del semaforo y productos inexistentes.
- La proteccion real contra doble envio en un sistema distribuido es una clave
  de idempotencia en el servidor (UUID unico) y una transaccion; en SQLite la PK
  de `cola_sync` demuestra el mismo principio.

## 5. Verificacion

- `pruebas_sqlite.sql`: C1, borrador confirmado, rollback y C7.
- `movil/evidencias/casos_c1_c7.txt`: C1 a C7 con resultados.
- `movil/verificacion_servidor.sql`: conteos de pedidos, lineas, productos y
  stock antes/despues.
- `docs/informe.pdf`: sintesis de 1.a, 1.b, 1.c, 2.a, 2.b, 2.c y 3.a, 3.b, 3.c.
