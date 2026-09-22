-- ============================================================
-- FOOD STORE — TPI (entrega parcial Unidades 1-3)
-- Objetivo 6 + características específicas de PostgreSQL:
--   * funciones PL/pgSQL de negocio (no solo de trigger)
--   * función de negocio que produce JSONB
--   * procedimiento almacenado invocado con CALL
--   * trigger a nivel sentencia con TABLA DE TRANSICIÓN
--     (REFERENCING NEW TABLE) + tabla de auditoría
--
-- Se aplica sobre la copia de trabajo:
--   BEGIN; \i sql/procedimientos.sql; COMMIT;
-- Idempotente: CREATE OR REPLACE / DROP TRIGGER IF EXISTS /
-- CREATE TABLE IF NOT EXISTS.
-- No modifica el DDL existente (schema.sql) ni las reglas R1-R10.
-- ============================================================

-- ------------------------------------------------------------
-- 1) Función PL/pgSQL de negocio
--    Total de un pedido = SUM(cantidad * precio_unitario) de sus
--    líneas. No se almacena "total" en pedido (3FN, ver schema):
--    el dato se deriva con esta función.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION calcular_total_pedido(p_pedido_id BIGINT)
RETURNS NUMERIC(12,2)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_total NUMERIC(12,2);
BEGIN
    SELECT COALESCE(SUM(d.cantidad * d.precio_unitario), 0)
      INTO v_total
      FROM detalle_pedido d
     WHERE d.pedido_id = p_pedido_id;

    RETURN v_total;
END;
$$;

-- ------------------------------------------------------------
-- 2) Función de negocio que produce JSONB
--    Resumen de un pedido en un único documento JSONB
--    (jsonb_build_object + jsonb_agg). Demuestra el uso del tipo
--    JSONB del motor en una operación de negocio.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION resumen_pedido_jsonb(p_pedido_id BIGINT)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_resumen JSONB;
BEGIN
    SELECT jsonb_build_object(
               'pedido',      pe.id,
               'fecha',       pe.fecha,
               'cliente',     jsonb_build_object('id', c.id, 'nombre', c.nombre, 'apellido', c.apellido),
               'forma_pago',  pe.forma_pago,
               'estado',      pe.estado,
               'lineas', jsonb_agg(
                   jsonb_build_object(
                       'producto',        p.nombre,
                       'cantidad',        d.cantidad,
                       'precio_unitario', d.precio_unitario,
                       'subtotal',        d.cantidad * d.precio_unitario
                   ) ORDER BY p.nombre
               ),
               'total', calcular_total_pedido(pe.id)
           )
      INTO v_resumen
      FROM pedido pe
      JOIN cliente c ON c.id = pe.cliente_id
      JOIN detalle_pedido d ON d.pedido_id = pe.id
      JOIN producto p ON p.id = d.producto_id
     WHERE pe.id = p_pedido_id
     GROUP BY pe.id, pe.fecha, c.id, c.nombre, c.apellido, pe.forma_pago, pe.estado;

    IF v_resumen IS NULL THEN
        RAISE EXCEPTION 'no existe el pedido %', p_pedido_id USING ERRCODE = 'P0002';
    END IF;

    RETURN v_resumen;
END;
$$;

-- ------------------------------------------------------------
-- 3) Procedimiento almacenado (PL/pgSQL) invocado con CALL
--    Registrar reposición de stock: aumenta el stock de un
--    producto activo. Complementa R9 (que solo descuenta al
--    vender) y valida en el motor: producto inactivo o cantidad
--    no positiva se rechazan. Nada de esto se puede resolver con
--    un simple UPDATE: queremos la regla VIVA en la base.
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE registrar_reposicion(
    p_producto_id BIGINT,
    p_cantidad    INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RAISE EXCEPTION 'la cantidad de reposición debe ser > 0 (se recibió %)',
            p_cantidad USING ERRCODE = 'P0001';
    END IF;

    UPDATE producto
       SET stock = stock + p_cantidad
     WHERE id = p_producto_id
       AND activo = TRUE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'producto % inexistente o dado de baja, no se repone',
            p_producto_id USING ERRCODE = 'P0001';
    END IF;
END;
$$;

-- ------------------------------------------------------------
-- 4) Auditoría de cargas masivas con TABLA DE TRANSICIÓN
--    Cada sentencia INSERT sobre detalle_pedido (que suele cargar
--    muchas líneas de golpe) genera UNA fila de auditoría con el
--    total de líneas y su monto. El trigger es a nivel SENTENCIA
--    y ve todas las filas insertadas a la vez a través de la
--    transición NEW TABLE.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS auditoria_carga_lineas (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    n_lineas      INTEGER       NOT NULL,
    monto_total   NUMERIC(12,2) NOT NULL,
    inserted_at   TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION auditar_carga_detalle_pedido()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_lineas INTEGER;
    v_monto  NUMERIC(12,2);
BEGIN
    SELECT count(*), COALESCE(sum(nueva.cantidad * nueva.precio_unitario), 0)
      INTO v_lineas, v_monto
      FROM nueva;

    INSERT INTO auditoria_carga_lineas (n_lineas, monto_total)
    VALUES (v_lineas, v_monto);

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_detalle_auditoria_carga ON detalle_pedido;
CREATE TRIGGER trg_detalle_auditoria_carga
    AFTER INSERT ON detalle_pedido
    REFERENCING NEW TABLE AS nueva
    FOR EACH STATEMENT
    EXECUTE FUNCTION auditar_carga_detalle_pedido();