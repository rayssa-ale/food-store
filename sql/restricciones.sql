-- ============================================================
-- FOOD STORE — TP2 (Base de Datos II)
-- Parte 1: Reglas de negocio garantizadas por el motor
-- R8/R9/R10 (ver DUIA parte 1 para la especificación completa)
--
-- Se aplica sobre la COPIA de trabajo:
--   BEGIN; \i sql/restricciones.sql; ... COMMIT;
-- Idempotente: las funciones se reemplazan y los triggers se
-- recrean (DROP IF EXISTS).
-- ============================================================

-- ------------------------------------------------------------
-- R8 — Transiciones de estado del pedido
--   * Un pedido en estado terminal (ENTREGADO, CANCELADO) no
--     puede cambiar de estado.
--   * El estado solo avanza por el flujo
--       PENDIENTE(1) -> EN_PREPARACION(2) -> ENTREGADO(3),
--     o se puede CANCELAR desde cualquier estado no terminal.
--     No se puede volver a un estado anterior.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION check_transicion_estado_pedido()
RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_ordinal_viejo int;
    v_ordinal_nuevo int;
    v_flujo         estado_pedido[] := ARRAY['PENDIENTE', 'EN_PREPARACION', 'ENTREGADO'];
BEGIN
    IF NEW.estado = OLD.estado THEN
        RETURN NEW;
    END IF;

    -- (a) estados terminales congelados
    IF OLD.estado IN ('ENTREGADO', 'CANCELADO') THEN
        RAISE EXCEPTION 'R8: pedido % en estado terminal (%), no puede cambiar a %',
            OLD.id, OLD.estado, NEW.estado
            USING ERRCODE = 'P0001';
    END IF;

    -- (b) cancelación permitida desde cualquier estado no terminal
    IF NEW.estado = 'CANCELADO' THEN
        RETURN NEW;
    END IF;

    -- apilar un estado intermedio se rechaza
    SELECT array_position(v_flujo, OLD.estado), array_position(v_flujo, NEW.estado)
        INTO v_ordinal_viejo, v_ordinal_nuevo;

    IF v_ordinal_nuevo IS NULL OR v_ordinal_nuevo <= v_ordinal_viejo THEN
        RAISE EXCEPTION 'R8: transición de estado inválida % -> %',
            OLD.estado, NEW.estado
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_pedido_estado_transicion ON pedido;
CREATE TRIGGER trg_pedido_estado_transicion
BEFORE UPDATE OF estado ON pedido
FOR EACH ROW EXECUTE FUNCTION check_transicion_estado_pedido();

-- ------------------------------------------------------------
-- R9 — Stock suficiente y descuento de stock al vender
--   Al INSERT de una línea de pedido se verifica que haya stock
--   disponible (producto activo y stock >= cantidad) y se lo
--   descuenta de forma atómica. El UPDATE condicional bloquea la
--   fila del producto, serializando ventas concurrentes del
--   mismo producto (evita sobreventa; ver Parte 2).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION verificar_y_descontar_stock()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE producto
       SET stock = stock - NEW.cantidad
     WHERE id = NEW.producto_id
       AND activo = TRUE
       AND stock >= NEW.cantidad;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'R9: stock insuficiente (o producto inactivo) para producto %, se piden % unidades',
            NEW.producto_id, NEW.cantidad
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_detalle_stock ON detalle_pedido;
CREATE TRIGGER trg_detalle_stock
BEFORE INSERT ON detalle_pedido
FOR EACH ROW EXECUTE FUNCTION verificar_y_descontar_stock();

-- ------------------------------------------------------------
-- R10 — Precio unitario de la línea congelado (refuerza R4)
--   El precio_unitario se congela al facturar; una vez creada la
--   línea no se puede modificar. Los descuentos o ajustes se
--   expresan con nuevas líneas, nunca alterando la historia.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION proteger_precio_unitario()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.precio_unitario IS DISTINCT FROM OLD.precio_unitario THEN
        RAISE EXCEPTION 'R10: el precio unitario de la línea % está congelado (R4)',
            OLD.id
            USING ERRCODE = 'P0001';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_detalle_precio_congelado ON detalle_pedido;
CREATE TRIGGER trg_detalle_precio_congelado
BEFORE UPDATE OF precio_unitario ON detalle_pedido
FOR EACH ROW EXECUTE FUNCTION proteger_precio_unitario();