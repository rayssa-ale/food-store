-- ============================================================
-- FOOD STORE — Proyecto integrador (Base de Datos I, UTN)
-- TP1 — Parte 4: DDL definitivo en PostgreSQL
-- Esquema conciliado entre el modelo relacional (Parte 2) y el
-- resultado de la normalización (Parte 3).
-- PostgreSQL 18+. Ejecutar completo, por ejemplo:
--   \i 'C:/.../schema.sql'
-- ============================================================

-- ------------------------------------------------------------
-- Dominios cerrados (tipos enumerados)
-- ------------------------------------------------------------

-- Formas de pago que usa el negocio (R3 / datos de la planilla).
CREATE TYPE forma_pago AS ENUM ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA');

-- Ciclo de vida de un pedido (atributo adicional razonable,
-- documentado en el diccionario de datos): permite seguir el
-- pedido sin recurrir a borrados; la baja se expresa con el
-- estado CANCELADO.
CREATE TYPE estado_pedido AS ENUM ('PENDIENTE', 'EN_PREPARACION', 'ENTREGADO', 'CANCELADO');

-- ------------------------------------------------------------
-- cliente
-- ------------------------------------------------------------
CREATE TABLE cliente (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(80)  NOT NULL,
    apellido    VARCHAR(80)  NOT NULL,
    email       VARCHAR(120) NOT NULL,
    telefono    VARCHAR(30),
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    -- R6: el mail identifica de forma única al cliente en el
    -- sistema (clave candidata alternativa de la Parte 1).
    CONSTRAINT uq_cliente_email UNIQUE (email)
);

-- ------------------------------------------------------------
-- categoria
-- ------------------------------------------------------------
CREATE TABLE categoria (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(80)  NOT NULL,
    descripcion VARCHAR(500),
    activo      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    -- Nombres de categoría sin duplicados: evita dos categorías
    -- homónimas ("Bebidas", "Bebidas"). Decisión de diseño a
    -- partir de la presentación del negocio.
    CONSTRAINT uq_categoria_nombre UNIQUE (nombre)
);

-- ------------------------------------------------------------
-- producto
-- ------------------------------------------------------------
CREATE TABLE producto (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(120)  NOT NULL,
    descripcion  VARCHAR(500),
    precio       NUMERIC(12,2) NOT NULL,
    stock        INTEGER       NOT NULL DEFAULT 0,
    categoria_id BIGINT        NOT NULL,
    activo       BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ   NOT NULL DEFAULT now(),
    -- R1: todo producto pertenece exactamente a una categoría
    -- (participación total).
    -- ON DELETE RESTRICT: R7 prohíbe eliminar físicamente
    -- categorías; se da de baja con activo = FALSE. Un SELECT
    -- que borre una categoría con productos se rechaza.
    CONSTRAINT fk_producto_categoria FOREIGN KEY (categoria_id)
        REFERENCES categoria (id) ON DELETE RESTRICT,
    -- R5: el precio y el stock nunca son negativos.
    CONSTRAINT ck_producto_precio_no_negativo CHECK (precio >= 0),
    CONSTRAINT ck_producto_stock_no_negativo  CHECK (stock >= 0)
);

-- ------------------------------------------------------------
-- pedido
-- ------------------------------------------------------------
CREATE TABLE pedido (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    cliente_id  BIGINT        NOT NULL,
    forma_pago  forma_pago    NOT NULL,
    estado      estado_pedido NOT NULL DEFAULT 'PENDIENTE',
    created_at  TIMESTAMPTZ   NOT NULL DEFAULT now(),
    -- R2: todo pedido pertenece exactamente a un cliente registrado
    -- (participación total).
    -- ON DELETE RESTRICT: un cliente con pedidos no se elimina
    -- físicamente; se conserva el historial de ventas completo.
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (cliente_id)
        REFERENCES cliente (id) ON DELETE RESTRICT
);
-- NOTA de diseño: no se almacena "total" del pedido. Es 100 %
-- derivable de sus líneas (SUM(cantidad * precio_unitario)).
-- Almacenarlo introduciría una dependencia transitiva (viola 3FN,
-- ver Parte 3) y no aporta trazabilidad: el precio histórico que
-- importa (precio_unitario por línea) ya se conserva.

-- ------------------------------------------------------------
-- detalle_pedido  (entidad asociativa de la relación N:M)
-- ------------------------------------------------------------
CREATE TABLE detalle_pedido (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pedido_id       BIGINT        NOT NULL,
    producto_id     BIGINT        NOT NULL,
    cantidad        INTEGER       NOT NULL,
    precio_unitario NUMERIC(12,2) NOT NULL,
    -- Clave candidata natural: el par (pedido_id, producto_id) no
    -- se repite (dentro de un mismo pedido, un producto no se pide
    -- en más de una línea — regla de la planilla, Parte 3). Se
    -- declara UNIQUE y se elige una clave sustituta (id) como PK
    -- para que futuras tablas (descuentos, observaciones por
    -- línea) puedan referenciar la línea con una sola FK.
    CONSTRAINT uq_detalle_pedido_producto UNIQUE (pedido_id, producto_id),
    -- R4: el precio unitario se congela al momento de facturar; por
    -- eso vive en la línea y no en producto.precio (que puede
    -- cambiar). Los montos usan NUMERIC (precisión fija), nunca
    -- punto flotante.
    -- ON DELETE RESTRICT: no se borra un pedido con líneas, ni un
    -- producto que ya se vendió: la historia no se pierde (R7).
    CONSTRAINT fk_detalle_pedido   FOREIGN KEY (pedido_id)
        REFERENCES pedido (id)    ON DELETE RESTRICT,
    CONSTRAINT fk_detalle_producto FOREIGN KEY (producto_id)
        REFERENCES producto (id)  ON DELETE RESTRICT,
    -- R4/R5: las cantidades pedidas son positivas y el precio
    -- unitario de la línea no es negativo.
    CONSTRAINT ck_detalle_cantidad_positiva      CHECK (cantidad > 0),
    CONSTRAINT ck_detalle_precio_unitario_no_neg CHECK (precio_unitario >= 0)
);

-- ------------------------------------------------------------
-- Índices (justificados por el uso esperado de las tablas)
-- ------------------------------------------------------------

-- 1. Acelera "listar / sumar los pedidos de un cliente"
--    (SELECT ... WHERE cliente_id = ?) y el agrupamiento por
--    cliente en reportes de facturación.
CREATE INDEX idx_pedido_cliente ON pedido (cliente_id);

-- 2. Acelera "listar productos vigentes de una categoría"
--    (SELECT ... WHERE categoria_id = ? AND activo = TRUE).
--    Índice parcial: solo indexa productos activos, que son los
--    que muestran la carta; no se gasta espacio con inactivos.
CREATE INDEX idx_producto_categoria ON producto (categoria_id)
    WHERE activo = TRUE;

-- 3. Acelera "cuánto se vendió de cada producto" (SUM por
--    producto) y permite reconstruir la N:M desde el lado producto
--    (detalles de un producto para hallar sus pedidos).
CREATE INDEX idx_detalle_producto ON detalle_pedido (producto_id);