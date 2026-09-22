# Registro del desafío de la competencia (TP3, Parte 5)

**Equipo G · Proyecto:** Food Store · **Fecha:** 22/09/2026
**Herramienta de IA:** OpenCode (CLI, modelo *big-pickle)

## Consulta fija de la competencia

Consulta de negocio con filtros y ordenamiento sobre la copia `food_store_tp3`
(50.006 productos activos, 3 categorías):

```sql
SELECT p.id, p.nombre, p.precio
FROM producto p
WHERE p.categoria_id = 2
  AND p.precio BETWEEN 600 AND 3000
  AND p.activo
ORDER BY p.precio, p.id
LIMIT 100;
```

## Estrategia aplicada (filtros + índices)

1. **Sin índice dedicado** (plan base): `Bitmap Index Scan` sobre
   `idx_producto_categoria` (columna única por categoría) + `Bitmap Heap Scan`
   que **re-filtra** el rango de precio en el heap (~16.700 activos de la
   categoría 2) + `Sort` manual por `precio, id`.
2. **Optimización propuesta por IA y aplicada** (OPT-1):
   `CREATE INDEX ix_producto_cat_precio ON producto (categoria_id, precio) WHERE activo;`
   — el índice parcial resuelve el filtro de precio en el árbol (`Index Cond`)
   y deja el orden `precio, id` **presorted** (el `Incremental Sort` solo
   ordena 4 grupos).

## Medición final (EXPLAIN (ANALYZE, BUFFERS), en caliente)

| Fase | Nodo dominante | Cost estimado | Execution Time real |
|---|---|---|---|
| **Antes** (sin índice dedicado) | Bitmap Index Scan `idx_producto_categoria` + Heap recheck + Sort | 0.00..289.41 | **14.242 ms** |
| **Después** (con `ix_producto_cat_precio`) | Index Scan `ix_producto_cat_precio` (103 filas) + Incremental Sort | 1.33..44.40 | **0.338 ms** |

**Mejora: 14.242 / 0.338 = ×42.**

## Detalle del plan ganador

```
Limit  (cost=1.33..44.40 rows=100 width=32) (actual time=0.173..0.296 rows=100 loops=1)
  ->  Incremental Sort  (cost=1.33..3827.37 ...) Sort Key: precio, id
         Presorted Key: precio · Full-sort Groups: 4
        ->  Index Scan using ix_producto_cat_precio on producto p
              Index Cond: ((categoria_id = 2) AND (precio >= '600') AND (precio <= '3000'))
              Actual: 103 filas · Index Searches: 1
Execution Time: 0.338 ms
```

## Transparencia: qué se probó y se descartó

- `ix_pedido_estado` (Q4): la hipótesis de la IA fue refutada por el plan
  (el cuello era el agregado de 500k líneas, no el filtro de estado) —
  documentado en `docs/informe_optimizacion.md` §2.2 y `docs/ejercicio_lectura_critica_planes_ia.md` §3.3.
- Covering index en `detalle_pedido` (Q3): aplicado, pero el optimizador
  desestimó el Index-Only Scan (agregado dominante) — mejora marginal, documentada.

Plan completo: `docs/planes/Q6_competencia_antes.txt` y `docs/planes/Q6_competencia_despues.txt`.