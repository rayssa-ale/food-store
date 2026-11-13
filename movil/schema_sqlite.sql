-- Food Store - Unidad 8
-- Base local de la tablet (SQLite 3.37+). El servidor PostgreSQL es la
-- fuente de verdad; estas tablas solo guardan una instantanea y borradores.
PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS snapshot_servidor;
DROP TABLE IF EXISTS cola_sync;
DROP TABLE IF EXISTS item_borrador;
DROP TABLE IF EXISTS pedido_borrador;
DROP TABLE IF EXISTS producto_cache;

-- Catalogo que viaja a la tablet. Precio en centavos para evitar REAL.
CREATE TABLE producto_cache (
    id              INTEGER PRIMARY KEY,
    nombre          TEXT    NOT NULL,
    precio_centavos INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock_visto     INTEGER NOT NULL CHECK (stock_visto >= 0),
    disponible      INTEGER NOT NULL CHECK (disponible IN (0, 1)),
    eliminado       INTEGER NOT NULL CHECK (eliminado IN (0, 1)),
    fecha_copia     TEXT    NOT NULL
) STRICT;

-- Borrador armado sin conexion. usuario es un alias local, nunca PII.
CREATE TABLE pedido_borrador (
    id_local   TEXT PRIMARY KEY,
    usuario    TEXT NOT NULL,
    forma_pago TEXT NOT NULL CHECK (forma_pago IN ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA')),
    fecha      TEXT NOT NULL
) STRICT;

-- Lineas del borrador. El precio visto queda congelado para el semaforo.
CREATE TABLE item_borrador (
    id_local              TEXT    NOT NULL,
    producto_id           INTEGER NOT NULL,
    cantidad              INTEGER NOT NULL CHECK (cantidad > 0),
    precio_centavos_visto INTEGER NOT NULL CHECK (precio_centavos_visto >= 0),
    PRIMARY KEY (id_local, producto_id),
    FOREIGN KEY (id_local) REFERENCES pedido_borrador (id_local) ON DELETE CASCADE,
    FOREIGN KEY (producto_id) REFERENCES producto_cache (id) ON DELETE RESTRICT
) STRICT;

-- Solicitudes de sincronizacion. SIMULADO_APROBADO no es una venta.
CREATE TABLE cola_sync (
    solicitud_uuid TEXT PRIMARY KEY,
    id_local       TEXT NOT NULL,
    estado         TEXT NOT NULL DEFAULT 'PENDIENTE'
                   CHECK (estado IN ('PENDIENTE', 'CONFLICTO', 'RECHAZADO', 'SIMULADO_APROBADO')),
    motivo         TEXT,
    creado_en      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    evaluado_en    TEXT,
    FOREIGN KEY (id_local) REFERENCES pedido_borrador (id_local) ON DELETE RESTRICT
) STRICT;

-- Tabla de apoyo para importar el CSV de psql. No es parte del modelo
-- operativo de la tablet; conserva t/f como texto para poder convertirlos.
CREATE TABLE snapshot_servidor (
    producto_id     INTEGER PRIMARY KEY,
    nombre          TEXT    NOT NULL,
    precio_centavos INTEGER NOT NULL,
    stock_visto     INTEGER NOT NULL,
    disponible      TEXT    NOT NULL,
    eliminado       TEXT    NOT NULL,
    fecha_copia     TEXT    NOT NULL
) STRICT;
