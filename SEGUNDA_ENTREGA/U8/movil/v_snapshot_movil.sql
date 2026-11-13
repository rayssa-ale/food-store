-- Instantanea de catalogo para la tablet. Solo datos no personales.
-- El precio se convierte a centavos y la baja logica se expone como
-- disponible = false / eliminado = true.
DROP VIEW IF EXISTS v_snapshot_movil;

CREATE VIEW v_snapshot_movil AS
SELECT
    p.id                              AS producto_id,
    p.nombre                          AS nombre,
    (p.precio * 100)::bigint          AS precio_centavos,
    p.stock                           AS stock_visto,
    (p.activo AND c.activo)           AS disponible,
    (NOT p.activo)                    AS eliminado,
    date_trunc('second', now())       AS fecha_copia
FROM producto p
JOIN categoria c ON c.id = p.categoria_id;
