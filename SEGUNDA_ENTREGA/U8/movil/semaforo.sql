-- Semaforo de sincronizacion (SQLite).
-- 1) Refresca producto_cache desde snapshot_servidor.
-- 2) Evalua SOLO solicitudes PENDIENTE.
-- 3) No escribe nada en PostgreSQL: SIMULADO_APROBADO no es una venta.
BEGIN;

INSERT INTO producto_cache (
    id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia
)
SELECT
    producto_id,
    nombre,
    precio_centavos,
    stock_visto,
    CASE lower(trim(disponible))
        WHEN 't' THEN 1 WHEN 'true' THEN 1 WHEN '1' THEN 1 ELSE 0
    END,
    CASE lower(trim(eliminado))
        WHEN 't' THEN 1 WHEN 'true' THEN 1 WHEN '1' THEN 1 ELSE 0
    END,
    fecha_copia
FROM snapshot_servidor
WHERE producto_id IS NOT NULL
ON CONFLICT (id) DO UPDATE SET
    nombre          = excluded.nombre,
    precio_centavos = excluded.precio_centavos,
    stock_visto     = excluded.stock_visto,
    disponible      = excluded.disponible,
    eliminado       = excluded.eliminado,
    fecha_copia     = excluded.fecha_copia;

WITH evaluacion AS (
    SELECT
        c.solicitud_uuid,
        SUM(CASE WHEN s.producto_id IS NULL THEN 1 ELSE 0 END) AS faltantes,
        SUM(CASE WHEN s.producto_id IS NOT NULL
                  AND lower(trim(s.eliminado)) IN ('t', 'true', '1')
                 THEN 1 ELSE 0 END) AS eliminados,
        SUM(CASE WHEN s.producto_id IS NOT NULL
                  AND lower(trim(s.eliminado)) NOT IN ('t', 'true', '1')
                  AND lower(trim(s.disponible)) NOT IN ('t', 'true', '1')
                 THEN 1 ELSE 0 END) AS no_disponibles,
        SUM(CASE WHEN s.producto_id IS NOT NULL
                  AND i.cantidad > s.stock_visto
                 THEN 1 ELSE 0 END) AS sin_stock,
        SUM(CASE WHEN s.producto_id IS NOT NULL
                  AND lower(trim(s.eliminado)) NOT IN ('t', 'true', '1')
                  AND lower(trim(s.disponible)) IN ('t', 'true', '1')
                  AND i.cantidad <= s.stock_visto
                  AND i.precio_centavos_visto <> s.precio_centavos
                 THEN 1 ELSE 0 END) AS precios_distintos,
        group_concat(DISTINCT CASE WHEN s.producto_id IS NULL
                                   THEN i.producto_id END) AS ids_faltantes,
        group_concat(DISTINCT CASE WHEN s.producto_id IS NOT NULL
                                    AND lower(trim(s.eliminado)) IN ('t', 'true', '1')
                                   THEN i.producto_id END) AS ids_eliminados,
        group_concat(DISTINCT CASE WHEN s.producto_id IS NOT NULL
                                    AND lower(trim(s.eliminado)) NOT IN ('t', 'true', '1')
                                    AND lower(trim(s.disponible)) NOT IN ('t', 'true', '1')
                                   THEN i.producto_id END) AS ids_no_disponibles,
        group_concat(DISTINCT CASE WHEN s.producto_id IS NOT NULL
                                    AND i.cantidad > s.stock_visto
                                   THEN i.producto_id END) AS ids_sin_stock,
        group_concat(DISTINCT CASE WHEN s.producto_id IS NOT NULL
                                    AND lower(trim(s.eliminado)) NOT IN ('t', 'true', '1')
                                    AND lower(trim(s.disponible)) IN ('t', 'true', '1')
                                    AND i.cantidad <= s.stock_visto
                                    AND i.precio_centavos_visto <> s.precio_centavos
                                   THEN i.producto_id END) AS ids_precio,
        MAX(s.fecha_copia) AS fecha_copia
    FROM cola_sync c
    JOIN item_borrador i ON i.id_local = c.id_local
    LEFT JOIN snapshot_servidor s ON s.producto_id = i.producto_id
    WHERE c.estado = 'PENDIENTE'
    GROUP BY c.solicitud_uuid
)
UPDATE cola_sync
SET estado = CASE
        WHEN e.faltantes + e.eliminados + e.no_disponibles + e.sin_stock > 0
            THEN 'RECHAZADO'
        WHEN e.precios_distintos > 0
            THEN 'CONFLICTO'
        ELSE 'SIMULADO_APROBADO'
    END,
    motivo = CASE
        WHEN e.faltantes + e.eliminados + e.no_disponibles + e.sin_stock > 0
            THEN 'RECHAZADO:'
                 || CASE WHEN e.faltantes > 0
                         THEN ' inexistente=' || COALESCE(e.ids_faltantes, '?') ELSE '' END
                 || CASE WHEN e.eliminados > 0
                         THEN ' eliminado=' || COALESCE(e.ids_eliminados, '?') ELSE '' END
                 || CASE WHEN e.no_disponibles > 0
                         THEN ' no_disponible=' || COALESCE(e.ids_no_disponibles, '?') ELSE '' END
                 || CASE WHEN e.sin_stock > 0
                         THEN ' stock_insuficiente=' || COALESCE(e.ids_sin_stock, '?') ELSE '' END
        WHEN e.precios_distintos > 0
            THEN 'CONFLICTO: precio_visto_distinto=' || COALESCE(e.ids_precio, '?')
        ELSE 'SIMULADO_APROBADO: coincide con instantanea ' || COALESCE(e.fecha_copia, '?')
    END,
    evaluado_en = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
FROM evaluacion e
WHERE cola_sync.solicitud_uuid = e.solicitud_uuid
  AND cola_sync.estado = 'PENDIENTE';

COMMIT;
