-- Pruebas de la base de la tablet (consigna 1.c).
-- Requiere schema_sqlite.sql + snapshot importado + semaforo.sql ejecutado
-- al menos una vez para que producto_cache tenga catalogo.
PRAGMA foreign_keys = ON;

-- C1: el catalogo se consulta sin servidor.
SELECT 'C1_catalogo_disponible' AS prueba,
       id, nombre, precio_centavos, stock_visto
FROM producto_cache
WHERE disponible = 1 AND eliminado = 0
ORDER BY id
LIMIT 5;

-- 1.c.1a: borrador completo en una transaccion confirmada.
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('11111111-1111-4111-8111-111111111111', 'vendedor_feria', 'EFECTIVO',
        '2026-11-12T10:00:00Z');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('11111111-1111-4111-8111-111111111111', 1, 2, 120000);
INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        '11111111-1111-4111-8111-111111111111', 'PENDIENTE', NULL);
COMMIT;

SELECT 'borrador_confirmado' AS control, count(*) AS filas
FROM pedido_borrador
WHERE id_local = '11111111-1111-4111-8111-111111111111';

-- 1.c.1b: operacion deshecha con ROLLBACK.
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('22222222-2222-4222-8222-222222222222', 'vendedor_feria', 'TARJETA',
        '2026-11-12T10:05:00Z');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('22222222-2222-4222-8222-222222222222', 1, 1, 120000);
ROLLBACK;

SELECT 'borrador_rollback' AS control, count(*) AS filas
FROM pedido_borrador
WHERE id_local = '22222222-2222-4222-8222-222222222222';

-- C7a: cantidad 0. El CHECK debe abortar y luego ROLLBACK deja 0 filas.
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('33333333-3333-4333-8333-333333333333', 'vendedor_feria', 'EFECTIVO',
        '2026-11-12T10:10:00Z');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('33333333-3333-4333-8333-333333333333', 1, 0, 120000);
ROLLBACK;

SELECT 'C7_cantidad_cero' AS control, count(*) AS filas
FROM pedido_borrador
WHERE id_local = '33333333-3333-4333-8333-333333333333';

-- C7b: producto inexistente. La FK debe abortar y luego ROLLBACK deja 0 filas.
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('44444444-4444-4444-8444-444444444444', 'vendedor_feria', 'TRANSFERENCIA',
        '2026-11-12T10:15:00Z');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('44444444-4444-4444-8444-444444444444', 999999, 1, 120000);
ROLLBACK;

SELECT 'C7_producto_inexistente' AS control, count(*) AS filas
FROM pedido_borrador
WHERE id_local = '44444444-4444-4444-8444-444444444444';
