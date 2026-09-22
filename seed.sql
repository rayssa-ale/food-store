-- ============================================================
-- FOOD STORE — Datos de carga inicial (seed)
-- Base de Datos I / II (UTN)
-- Carga de ejemplo mínima para los TP2 de concurrencia e
-- integridad: categorías, productos, clientes, pedidos y líneas.
-- Debe ejecutarse DESPUÉS de schema.sql, sobre la COPIA de
-- trabajo (ver protocolo_seguridad.md). Ids explícitos con
-- OVERRIDING SYSTEM VALUE para poder referenciarlos con
-- precisión en los labs.
-- ============================================================

BEGIN;

INSERT INTO categoria (id, nombre, descripcion, activo) OVERRIDING SYSTEM VALUE VALUES
    (1, 'Pizzas',   'Pizzas artesanales a la piedra',  TRUE),
    (2, 'Bebidas',  'Gaseosas, aguas y cervezas',       TRUE),
    (3, 'Postres',  'Postres caseros del día',          TRUE);

INSERT INTO producto (id, nombre, descripcion, precio, stock, categoria_id, activo) OVERRIDING SYSTEM VALUE VALUES
    (1, 'Muzzarella',              'Grande, salsa y queso muzzarella',  1200.00, 10, 1, TRUE),
    (2, 'Napolitana',              'Grande, tomate y ajo',              1500.00,  8, 1, TRUE),
    (3, 'Jamón y Queso',           'Grande, jamón cocido y queso',      1400.00,  5, 1, TRUE),
    (4, 'Coca-Cola 1L',            'Gaseosa cola, 1 litro',              850.00, 50, 2, TRUE),
    (5, 'Agua mineral 500ml',      'Agua sin gas, botella PET',          500.00, 30, 2, TRUE),
    (6, 'Flan con dulce de leche', 'Flan casero, porción',               950.00, 12, 3, TRUE);

INSERT INTO cliente (id, nombre, apellido, email, telefono) OVERRIDING SYSTEM VALUE VALUES
    (1, 'Dana',   'Da Luz',   'dana.daluz@gmail.com',   '3511234567'),
    (2, 'Carlos', 'Abregú',   'carlos.abregu@outlook.com', '3519876543'),
    (3, 'Ramiro', 'Fariña',   'ramiro.farina@gmail.com', '3515551122');

INSERT INTO pedido (id, fecha, cliente_id, forma_pago, estado) OVERRIDING SYSTEM VALUE VALUES
    (1, '2026-09-20 20:15:00-03', 1, 'TARJETA',       'ENTREGADO'),
    (2, '2026-09-21 21:30:00-03', 2, 'EFECTIVO',      'EN_PREPARACION'),
    (3, now(),                    3, 'TRANSFERENCIA', 'PENDIENTE');

INSERT INTO detalle_pedido (id, pedido_id, producto_id, cantidad, precio_unitario) OVERRIDING SYSTEM VALUE VALUES
    (1, 1, 1, 2, 1200.00),
    (2, 1, 4, 1,  850.00),
    (3, 2, 2, 1, 1500.00),
    (4, 2, 5, 2,  500.00),
    (5, 3, 6, 3,  950.00);

COMMIT;