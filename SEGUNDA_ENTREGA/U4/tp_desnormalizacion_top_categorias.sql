-- ============================================================
-- FOOD STORE — Unidad 4 · TP6 · Parte 2
-- Desnormalización controlada para el top 5 de categorías por
-- monto vendido en el día.
--
-- Entregable: tp_desnormalizacion_top_categorias.sql
-- Base de trabajo: food_store_tp6 (copia de food_store_tp5)
--
--   & $psql -U postgres -h localhost -d food_store_tp6 \
--       -v ON_ERROR_STOP=1 -f TP6/tp_desnormalizacion_top_categorias.sql
--
-- ------------------------------------------------------------
-- 0. La consulta del enunciado (5.1) y su traducción al esquema
--    real de Food Store
-- ------------------------------------------------------------
-- El enunciado escribe:
--
--   SELECT c.nombre, SUM(dp.subtotal) ...
--   ... AND dp.eliminado = FALSE AND ped.eliminado = FALSE
--
-- Food Store NO tiene esas columnas, y no es un detalle menor:
--
--  * `detalle_pedido` guarda el precio congelado R4 como
--    `cantidad` + `precio_unitario`. No existe `subtotal`: el
--    subtotal ES la expresión cantidad * precio_unitario, que es
--    justamente lo que se agrega en el GROUP BY.
--  * La baja lógica no es una bandera `eliminado` sino el ENUM
--    `estado_pedido` (TP1 lo decidió así y R7 prohíbe el borrado
--    físico). El equivalente de `eliminado = FALSE` es por tanto
--    `estado <> 'CANCELADO'`. No se estrecha a `= 'ENTREGADO'`:
--    eso sería otro reporte (es el que usa la vista materializada
--    de TP5, con otra especificación).
--
-- Corregimos el filtro por el día usando un predicado de RANGO en
-- lugar de `ped.fecha = CURRENT_DATE`. Motivo medido: `fecha` es
-- TIMESTAMPTZ y CURRENT_DATE es DATE, así que la igualdad se
-- resuelve comparar contra la medianoche local exacta. Sobre el
-- día más cargado que ya traía la base (2026-09-22, 12.269
-- pedidos):
--
--   fecha = CURRENT_DATE .............................     0 filas
--   fecha >= CURRENT_DATE AND fecha < CURRENT_DATE+1 ... 12.269 filas
--
-- Con el predicado literal del enunciado la consulta devuelve el
-- conjunto vacío y EXPLAIN no mide nada. El predicado de rango es
-- equivalente a `fecha::date = CURRENT_DATE` y además es
-- sargable: puede usar ix_pedido_fecha_estado.
--
-- La versión adaptada que se mide es, entonces:
--
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 5.2(a) LÍNEA BASE: la consulta normalizada de 4 tablas.
-- Plan archivado en TP6/planes/D1_top5_categorias_antes.txt
--
-- Resultado medido sobre 15.000 pedidos / 37.500 líneas del día:
--
--   Execution Time: 233,234 ms en frío · mediana 138 ms en calor
--   (corridas 130,268 / 137,602 / 138,280 / 140,289 / 154,845)
--
-- Nodo dominante:
--   Parallel Seq Scan on public.detalle_pedido
--   rows=228970 estimadas · 183.176 filas por worker x 3
--   = 549.529 filas LEÍDAS para responder sobre 31.372 líneas.
--   Buffers: shared hit=1724 read=3280
--
-- Es decir: un barrido secuencial de la tabla de líneas completa,
-- 17,5 veces más datos que los que la pregunta necesita. La causa
-- del plan no es que falte un índice, sino que el estimador fallen
-- antes: para el filtro de estado calculó rows=6445 cuando el día
-- tiene 12.529 pedidos no cancelados (subestimó ~2x, porque el
-- histograma de `estado` supone reparto uniforme entre 4 estados y
-- los CANCELADO son el 16 %), y con esa subestimación descartó el
-- Nested Loop con el índice de detalle_pedido(pedido_id, ...).
--
-- Qué patrón elegir y por qué se responde en el informe; la
-- decisión corta: ESTRUCTURA AGREGADA PRECALCULADA CON
-- DISPARADORES, y NO vista materializada, porque el panel pide
-- "tiempo real" (una MV exige un REFRESH que lo demuele) y porque
-- TP5 ya midió el patrón MV para grano mes/forma de pago con otro
-- propósito.
-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- 5.2(c) ESTRUCTURA DESNORMALIZADA
--
-- fact_venta_categoria_dia es un agregado precalculado con grano
-- (día, categoría). Duplica a propósito tres cosas que en el
-- esquema normalizado viven separadas o se derivan:
--
--   total_vendido     derivado por SUM(cantidad*precio_unitario)
--                      sobre el recorrido de 4 tablas
--   categoria_nombre  vive en categoria; aquí se copia para que
--                      el panel lea una sola tabla
--   lineas            derivado por COUNT(*)
--
-- Clave primaria (fecha, categoria_id). No hay clave sustituta:
-- el grano ES la identidad de la fila y así la clave primaria
-- coincide con la clave natural, que además es lo que habilita los
-- upserts incrementales sobre el cubo.
--
-- Monto NUMERIC(14,2): el 12,2 alcanza para el precio de una línea,
-- pero el agregado por día y categoría puede superarlo.
-- ============================================================

DROP TABLE IF EXISTS fact_venta_categoria_dia;

CREATE TABLE fact_venta_categoria_dia (
    fecha            DATE         NOT NULL,
    categoria_id     BIGINT       NOT NULL,
    categoria_nombre VARCHAR(80)  NOT NULL,
    total_vendido    NUMERIC(14,2) NOT NULL DEFAULT 0,
    lineas           INTEGER      NOT NULL DEFAULT 0,
    actualizado_en   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_fact_venta_categoria_dia PRIMARY KEY (fecha, categoria_id),
    CONSTRAINT fk_fact_venta_categoria FOREIGN KEY (categoria_id)
        REFERENCES categoria (id) ON DELETE RESTRICT,
    CONSTRAINT ck_fact_venta_total_no_negativo CHECK (total_vendido >= 0),
    CONSTRAINT ck_fact_venta_lineas_no_negativas CHECK (lineas >= 0)
);

-- El reporte lee (fecha, categoria) y ordena por total_vendido:
-- un índice parcial sobre el día corriente no sirve (CURRENT_DATE
-- no es inmutable), pero el índice sobre total_vendido sí ayuda
-- al ORDER BY ... LIMIT y se paga con muy pocas filas.
CREATE INDEX ix_fact_venta_total ON fact_venta_categoria_dia (total_vendido DESC);

-- ============================================================
-- MECANISMO DE SINCRONIZACIÓN
--
-- Regla de oro: toda escritura que pueda mover el agregado tiene
-- un disparador que lo mueve en la MISMA transacción. Por eso la
-- estructura no puede quedar desincronizada si la transacción
-- confirma: o escriben las dos cosas, o no escribe ninguna.
--
-- Se distinguen dos caminos:
--
--  * CAMINO CALIENTE (línea a línea): INSERT/DELETE de
--    detalle_pedido ajusta el cubo con un delta O(1). Es la
--    operación del mostrador del panel, no puede permitirse el
--    costo de recalcular el día.
--
--  * CAMINO FRÍO (cambios raros y de alcance ancho): mover la
--    fecha de un pedido, cancelar un pedido o recategorizar un
--    producto afecta muchas líneas; ahí se RECALCULA el día
--    afectado entero con la misma agregación del auditor. Es
--    recalcular, no propagar el impacto a mano, y por eso es
--    correcto por construcción.
--
-- Cada camino decide por sí mismo si la línea cuenta, con la
-- misma regla que usa la consulta original: cuenta si su pedido
-- no está CANCELADO.
-- ============================================================

-- ------------------------------------------------------------
-- Primitiva 1: ajuste incremental de un cubo (camino caliente).
-- p_monto / p_lineas pueden venir en negativo (descontar).
-- Si el cubo queda sin líneas se borra, para que la estructura
-- tenga exactamente las mismas filas que devolvería el GROUP BY
-- de la consulta normalizada (una categoría totalmente cancelada
-- no debe aparecer con total 0).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION ajustar_fact_venta(
    p_fecha        DATE,
    p_producto_id  BIGINT,
    p_monto        NUMERIC,
    p_lineas       INTEGER
) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
    v_cat BIGINT;
BEGIN
    SELECT p.categoria_id INTO v_cat
      FROM producto p
     WHERE p.id = p_producto_id;

    IF v_cat IS NULL THEN
        RETURN;                       -- producto borrado: nada que ajustar
    END IF;

    INSERT INTO fact_venta_categoria_dia AS f
        (fecha, categoria_id, categoria_nombre, total_vendido, lineas)
    SELECT p_fecha, v_cat, c.nombre, p_monto, p_lineas
      FROM categoria c
     WHERE c.id = v_cat
    ON CONFLICT (fecha, categoria_id) DO UPDATE
       SET total_vendido  = f.total_vendido  + EXCLUDED.total_vendido,
           lineas         = f.lineas         + EXCLUDED.lineas,
           actualizado_en = now();

    DELETE FROM fact_venta_categoria_dia
     WHERE fecha = p_fecha
       AND categoria_id = v_cat
       AND lineas <= 0;
END;
$$;

-- ------------------------------------------------------------
-- Primitiva 2: recálculo completo de un día (camino frío).
-- Es LITERALMENTE la agregación del punto 5.1, sin LIMIT: si el
-- día queda igual, el agregado queda igual. Esta es la garantía
-- de no desincronización para todo lo que no sea una línea nueva.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION recalcular_fact_venta_dia(p_fecha DATE)
RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM fact_venta_categoria_dia
     WHERE fecha = p_fecha;

    INSERT INTO fact_venta_categoria_dia
        (fecha, categoria_id, categoria_nombre, total_vendido, lineas)
    SELECT pe.fecha::date, c.id, c.nombre,
           SUM(d.cantidad * d.precio_unitario),
           COUNT(*)
      FROM pedido pe
      JOIN detalle_pedido d ON d.pedido_id = pe.id
      JOIN producto      p ON p.id = d.producto_id
      JOIN categoria     c ON c.id = p.categoria_id
     WHERE pe.fecha::date = p_fecha
       AND pe.estado <> 'CANCELADO'
     GROUP BY pe.fecha::date, c.id, c.nombre;
END;
$$;

-- ------------------------------------------------------------
-- Disparadores del camino caliente: detalle_pedido
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_detalle_fact_insert() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_cancelled BOOLEAN;
BEGIN
    -- La línea cuenta solo si su pedido no está cancelado: misma
    -- regla que el WHERE de la consulta original.
    SELECT (pe.estado = 'CANCELADO') INTO v_cancelled
      FROM pedido pe WHERE pe.id = NEW.pedido_id;

    IF COALESCE(v_cancelled, TRUE) = FALSE THEN
        PERFORM ajustar_fact_venta(
            (SELECT pe.fecha::date FROM pedido pe WHERE pe.id = NEW.pedido_id),
            NEW.producto_id,
            NEW.cantidad * NEW.precio_unitario,
            1);
    END IF;

    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION trg_detalle_fact_delete() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_cancelled BOOLEAN;
BEGIN
    -- Al borrar hay que descontar solo si la línea estaba
    -- contabilizada, y eso depende del estado ACTUAL del pedido.
    SELECT (pe.estado = 'CANCELADO') INTO v_cancelled
      FROM pedido pe WHERE pe.id = OLD.pedido_id;

    IF COALESCE(v_cancelled, TRUE) = FALSE THEN
        PERFORM ajustar_fact_venta(
            (SELECT pe.fecha::date FROM pedido pe WHERE pe.id = OLD.pedido_id),
            OLD.producto_id,
            -(OLD.cantidad * OLD.precio_unitario),
            -1);
    END IF;

    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION trg_detalle_fact_update() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    -- Una línea vivida no cambia de cantidad, producto ni pedido:
    -- R10 congela precio_unitario y la clave candidata
    -- (pedido_id, producto_id) es UNIQUE. Si aun así se toca
    -- alguna de las columnas que definen el cubo, se recalculan
    -- los dos días afectados en vez de intentar un delta: es más
    -- barato que este caso y no puede quedar mal.
    IF NEW.pedido_id IS DISTINCT FROM OLD.pedido_id
       OR NEW.producto_id IS DISTINCT FROM OLD.producto_id
       OR NEW.cantidad    IS DISTINCT FROM OLD.cantidad
       OR NEW.precio_unitario IS DISTINCT FROM OLD.precio_unitario THEN
        PERFORM recalcular_fact_venta_dia(
            (SELECT pe.fecha::date FROM pedido pe WHERE pe.id = OLD.pedido_id));
        PERFORM recalcular_fact_venta_dia(
            (SELECT pe.fecha::date FROM pedido pe WHERE pe.id = NEW.pedido_id));
    END IF;

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_detalle_fact_ins ON detalle_pedido;
CREATE TRIGGER trg_detalle_fact_ins
    AFTER INSERT ON detalle_pedido
    FOR EACH ROW EXECUTE FUNCTION trg_detalle_fact_insert();

DROP TRIGGER IF EXISTS trg_detalle_fact_del ON detalle_pedido;
CREATE TRIGGER trg_detalle_fact_del
    AFTER DELETE ON detalle_pedido
    FOR EACH ROW EXECUTE FUNCTION trg_detalle_fact_delete();

DROP TRIGGER IF EXISTS trg_detalle_fact_upd ON detalle_pedido;
CREATE TRIGGER trg_detalle_fact_upd
    AFTER UPDATE ON detalle_pedido
    FOR EACH ROW EXECUTE FUNCTION trg_detalle_fact_update();

-- ------------------------------------------------------------
-- Disparadores del camino frío: pedido
--
-- Un cambio de fecha mueve el pedido de un día a otro, y una
-- cancelación saca todas sus líneas del agregado. Los dos casos
-- se resuelven recalculando el día (o los dos días) completo.
--
-- R8 impide volver desde un estado terminal, así que la única
-- frontera que se cruza es entrar en CANCELADO; el disparador
-- igual compara ambos estados para no depender de esa regla.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_pedido_fact_update() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.fecha IS DISTINCT FROM OLD.fecha THEN
        PERFORM recalcular_fact_venta_dia(OLD.fecha::date);
        PERFORM recalcular_fact_venta_dia(NEW.fecha::date);
    END IF;

    IF (NEW.estado = 'CANCELADO') IS DISTINCT FROM (OLD.estado = 'CANCELADO') THEN
        PERFORM recalcular_fact_venta_dia(NEW.fecha::date);
    END IF;

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_pedido_fact_upd ON pedido;
CREATE TRIGGER trg_pedido_fact_upd
    AFTER UPDATE ON pedido
    FOR EACH ROW EXECUTE FUNCTION trg_pedido_fact_update();

-- Un pedido que nace y muere en la misma transacción no necesita
-- ajuste: sus líneas nacen con sus propios disparadores.

-- ------------------------------------------------------------
-- Disparador del camino frío: producto (recategorización)
--
-- Cambiar la categoría de un producto invalida todo lo vendido
-- de ese producto, en todas las fechas. Se recalculan los días
-- en los que el producto tenga líneas contabilizadas.
--
-- Esto es lo que hace que la copia de categoria_nombre sea
-- segura: si el producto se mueve de categoría, sus montos salen
-- del cubo viejo (por el recálculo) y entran en el nuevo.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_producto_fact_categoria() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    r RECORD;
BEGIN
    IF NEW.categoria_id IS DISTINCT FROM OLD.categoria_id THEN
        FOR r IN
            SELECT DISTINCT pe.fecha::date AS dia
              FROM detalle_pedido d
              JOIN pedido pe ON pe.id = d.pedido_id
             WHERE d.producto_id = NEW.id
               AND pe.estado <> 'CANCELADO'
        LOOP
            PERFORM recalcular_fact_venta_dia(r.dia);
        END LOOP;
    END IF;

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_producto_fact_cat ON producto;
CREATE TRIGGER trg_producto_fact_cat
    AFTER UPDATE OF categoria_id ON producto
    FOR EACH ROW EXECUTE FUNCTION trg_producto_fact_categoria();

-- ------------------------------------------------------------
-- Disparador del camino frío: categoria (renombre)
--
-- La columna categoria_nombre es una copia. Si la categoría se
-- renombra, la copia se propaga. Sin esto, el panel mostraría el
-- nombre viejo y el auditor de 5.2(e) lo detectaría.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_categoria_fact_nombre() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.nombre IS DISTINCT FROM OLD.nombre THEN
        UPDATE fact_venta_categoria_dia
           SET categoria_nombre = NEW.nombre
         WHERE categoria_id = NEW.id;
    END IF;

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_categoria_fact_nombre ON categoria;
CREATE TRIGGER trg_categoria_fact_nombre
    AFTER UPDATE OF nombre ON categoria
    FOR EACH ROW EXECUTE FUNCTION trg_categoria_fact_nombre();

-- ------------------------------------------------------------
-- POBLADO INICIAL (backfill)
--
-- Los disparadores nacen con la estructura, así que la carga
-- histórica que ya estaba en la base no pasó por ellos: se
-- puebla con la MISMA agregación del auditor, para todos los días.
-- Es la operación de reversibilidad: DROP + este backfill
-- reconstruye el estado exacto desde la fuente de verdad.
--
-- El disparador de R9 (stock) se apaga durante el backfill
-- porque el backfill NO inserta líneas, solo lee: se apaga
-- alrededor del INSERT ... SELECT por si el lector reescribiera
-- algo, y se vuelve a encender inmediatamente.
-- ------------------------------------------------------------
ALTER TABLE detalle_pedido DISABLE TRIGGER trg_detalle_stock;

INSERT INTO fact_venta_categoria_dia
    (fecha, categoria_id, categoria_nombre, total_vendido, lineas)
SELECT pe.fecha::date,
       c.id,
       c.nombre,
       SUM(d.cantidad * d.precio_unitario),
       COUNT(*)
  FROM pedido pe
  JOIN detalle_pedido d ON d.pedido_id = pe.id
  JOIN producto      p ON p.id = d.producto_id
  JOIN categoria     c ON c.id = p.categoria_id
 WHERE pe.estado <> 'CANCELADO'
 GROUP BY pe.fecha::date, c.id, c.nombre;

ALTER TABLE detalle_pedido ENABLE TRIGGER trg_detalle_stock;

ANALYZE fact_venta_categoria_dia;

-- Control de carga: un cubo por (día, categoría) con ventas.
SELECT count(*) AS cubos_cargados,
       min(fecha) AS dia_mas_antiguo,
       max(fecha) AS dia_mas_reciente
  FROM fact_venta_categoria_dia;

COMMIT;

-- ============================================================
-- 5.2(d) LA MISMA CONSULTA, LEYENDO LA ESTRUCTURA
--
-- Mismo resultado, sin tocar detalle_pedido, producto, pedido ni
-- categoria: un recorrido del cubo del día y un ORDER BY sobre
-- una tabla de tres filas.
-- ============================================================
EXPLAIN (ANALYZE, BUFFERS, SETTINGS)
SELECT fv.categoria_nombre AS categoria,
       fv.total_vendido
  FROM fact_venta_categoria_dia fv
 WHERE fv.fecha = CURRENT_DATE
 ORDER BY fv.total_vendido DESC
 LIMIT 5;

-- ------------------------------------------------------------
-- Equivalencia del reporte: el antes y el después deben dar las
-- mismas filas. Es el mismo criterio EXCEPT que ya se usó en
-- TP4/TP5 para las equivalencias de consultas.
-- ------------------------------------------------------------
WITH antes AS (
    SELECT c.nombre AS categoria,
           SUM(d.cantidad * d.precio_unitario) AS total_vendido
      FROM detalle_pedido d
      JOIN pedido   pe ON pe.id = d.pedido_id
      JOIN producto p  ON p.id = d.producto_id
      JOIN categoria c ON c.id = p.categoria_id
     WHERE pe.fecha >= CURRENT_DATE
       AND pe.fecha <  CURRENT_DATE + INTERVAL '1 day'
       AND pe.estado <> 'CANCELADO'
     GROUP BY c.nombre
),
despues AS (
    SELECT fv.categoria_nombre AS categoria,
           fv.total_vendido
      FROM fact_venta_categoria_dia fv
     WHERE fv.fecha = CURRENT_DATE
)
SELECT 'solo_antes' AS diferencia, * FROM (SELECT * FROM antes EXCEPT ALL SELECT * FROM despues) x
UNION ALL
SELECT 'solo_despues',           * FROM (SELECT * FROM despues EXCEPT ALL SELECT * FROM antes) y;

-- ============================================================
-- 5.2(e) AUDITORÍA DE DESINCRONIZACIÓN
--
-- Recalcula el agregado desde la fuente de verdad (las cuatro
-- tablas, sin usar fact_venta_categoria_dia) y compara con lo
-- almacenado, en las DOS direcciones. Si no hay diferencias el
-- resultado es vacío; cualquier fila que aparezca es un cubo mal
-- sincronizado, con su fecha, categoría y la diferencia de monto.
--
-- Se comparan los TRES datos redundantes, no sólo el monto:
-- total_vendido, lineas y categoria_nombre.
-- ============================================================
WITH verdad AS (
    SELECT pe.fecha::date              AS fecha,
           c.id                        AS categoria_id,
           c.nombre                    AS categoria_nombre,
           SUM(d.cantidad * d.precio_unitario)::NUMERIC(14,2) AS total_vendido,
           COUNT(*)                    AS lineas
      FROM pedido pe
      JOIN detalle_pedido d ON d.pedido_id = pe.id
      JOIN producto      p ON p.id = d.producto_id
      JOIN categoria     c ON c.id = p.categoria_id
     WHERE pe.estado <> 'CANCELADO'
     GROUP BY pe.fecha::date, c.id, c.nombre
),
almacenado AS (
    SELECT fecha, categoria_id, categoria_nombre, total_vendido, lineas
      FROM fact_venta_categoria_dia
),
diferencias AS (
    (SELECT 'cubo_faltante'::TEXT AS tipo, * FROM verdad
      EXCEPT ALL
     SELECT 'cubo_faltante', * FROM almacenado)
    UNION ALL
    (SELECT 'monto_o_lineas_o_nombre_distinto'::TEXT, *
       FROM almacenado
      EXCEPT ALL
     SELECT 'monto_o_lineas_o_nombre_distinto', *
       FROM verdad)
)
SELECT tipo, fecha, categoria_id, categoria_nombre, total_vendido, lineas
  FROM diferencias
 ORDER BY fecha, categoria_id;

-- ------------------------------------------------------------
-- Prueba de que la auditoría tiene dientes: se rompe el dato a
-- propósito y se la vuelve a correr. Debe acusar la diferencia;
-- después se restaura y la auditoría vuelve a dar vacío.
-- (Va en su propia transacción y se revierte: no toca el estado
--  final de la base.)
-- ------------------------------------------------------------
BEGIN;
UPDATE fact_venta_categoria_dia
   SET total_vendido = total_vendido + 1
 WHERE fecha = CURRENT_DATE;

WITH verdad AS (
    SELECT pe.fecha::date AS fecha, c.id AS categoria_id, c.nombre AS categoria_nombre,
           SUM(d.cantidad * d.precio_unitario)::NUMERIC(14,2) AS total_vendido,
           COUNT(*) AS lineas
      FROM pedido pe
      JOIN detalle_pedido d ON d.pedido_id = pe.id
      JOIN producto      p ON p.id = d.producto_id
      JOIN categoria     c ON c.id = p.categoria_id
     WHERE pe.estado <> 'CANCELADO'
     GROUP BY 1,2,3
),
almacenado AS (
    SELECT fecha, categoria_id, categoria_nombre, total_vendido, lineas
      FROM fact_venta_categoria_dia
)
SELECT tipo, fecha, categoria_id FROM (
    (SELECT 'cubo_faltante'::TEXT AS tipo, * FROM verdad EXCEPT ALL SELECT 'cubo_faltante', * FROM almacenado)
    UNION ALL
    (SELECT 'monto_o_lineas_o_nombre_distinto', * FROM almacenado EXCEPT ALL SELECT 'monto_o_lineas_o_nombre_distinto', * FROM verdad)
) d ORDER BY fecha, categoria_id;

ROLLBACK;   -- la base queda como estaba

-- ============================================================
-- PRUEBA DEL MECANISMO DE SINCRONIZACIÓN
--
-- Insertar, cancelar y borrar tienen que mover el agregado. Se
-- hace sobre un pedido real del día y se comprueba que el cubo
-- responde; todo dentro de una transacción que se revierte.
-- ============================================================
BEGIN;
SELECT fv.total_vendido AS total_antes, fv.lineas AS lineas_antes
  FROM fact_venta_categoria_dia fv
 WHERE fv.fecha = CURRENT_DATE
   AND fv.categoria_id = (SELECT pr.categoria_id FROM producto pr WHERE pr.id = 1);

-- 1) línea nueva (camino caliente: ajuste incremental)
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
SELECT (SELECT min(id) FROM pedido
         WHERE fecha >= CURRENT_DATE AND fecha < CURRENT_DATE + INTERVAL '1 day'
           AND estado = 'PENDIENTE'),
       1, 2, 1000.00;

SELECT fv.total_vendido AS total_despues_insert, fv.lineas AS lineas_despues_insert
  FROM fact_venta_categoria_dia fv
 WHERE fv.fecha = CURRENT_DATE
   AND fv.categoria_id = (SELECT pr.categoria_id FROM producto pr WHERE pr.id = 1);

-- 2) cancelación del pedido (camino frío: recálculo del día)
UPDATE pedido SET estado = 'CANCELADO'
 WHERE id = (SELECT min(id) FROM pedido
              WHERE fecha >= CURRENT_DATE AND fecha < CURRENT_DATE + INTERVAL '1 day'
                AND estado = 'PENDIENTE');

SELECT fv.total_vendido AS total_tras_cancelar, fv.lineas AS lineas_tras_cancelar
  FROM fact_venta_categoria_dia fv
 WHERE fv.fecha = CURRENT_DATE
   AND fv.categoria_id = (SELECT pr.categoria_id FROM producto pr WHERE pr.id = 1);

ROLLBACK;

-- ============================================================
-- REVERSIBILIDAD
--
-- La estructura no aporta información que no esté en las cuatro
-- tablas: es 100 % derivable. Deshacerse es un DROP y volver a
-- construirla es el backfill de arriba.
--
--   DROP TABLE fact_venta_categoria_dia CASCADE;
--   -- y volver a correr este mismo script desde el backfill
-- ============================================================