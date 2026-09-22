# Informe de equivalencia de consultas (TP3, Parte 4)

**Materia:** Base de Datos II — UTN · **Proyecto:** Food Store
**Base:** `food_store_tp3` · **Script:** `sql/equivalencias_consultas.sql`

Dos requisitos en lenguaje natural. Cada uno se entregó como SQL generado por
IA (versión A) y una versión alternativa de la **misma** semántica (versión B).
La equivalencia se comprobó con `EXCEPT` en **ambas direcciones**: si
`(A EXCEPT B)` y `(B EXCEPT A)` devuelven 0 filas, los conjuntos son iguales.

## Espec 1 — resumen/agregación

> *Listar cada categoría vigente con la cantidad de productos vigentes que
> tiene, incluyendo las categorías sin productos vigentes (0), ordenado de
> mayor a menor cantidad.*

- **A (IA):** `LEFT JOIN` sobre `producto` filtrado por `activo` + `COUNT(p.id)`.
- **B (alternativa):** subconsulta escalar `(SELECT COUNT(*) ...)`.
- Resultado esperado: 3 filas (3 categorías vigentes, 1 con 0 productos).
- Verificación: `A=B=3 filas` · `A−B = 0` · `B−A = 0` ✔

## Espec 2 — comparación con un agregado global

> *Clientes que hayan facturado más que el promedio facturado por cliente,
> considerando solo pedidos ENTREGADO. Mostrar id, apellido, nombre y total
> facturado, de mayor a menor.*

- **A (IA):** `GROUP BY` + `HAVING SUM(...) > (SELECT AVG(f) FROM (...))`.
- **B (alternativa):** CTE de totales + CTE del promedio + comparación.
- Resultado esperado: coincidir en número de filas y contenido.
- Verificación: `A=B=9.088 filas` · `A−B = 0` · `B−A = 0` ✔

## Errores que la verificación EXCEPT destapó

1. **Correlación accidental:** en la subconsulta de A (y en la del HAVING) el
   alias del detalle interno quedó como `d` (externo) en vez de `d2`; la query
   corría pero correlacionaba contra el detalle del cliente externo, rompiendo
   la semántica (A daba 0 filas vs 9.088 de B). El `EXCEPT` con dirección
   detectó la discrepancia; se corrigió a `d2` y quedó documentado en el script.
2. **Ámbito de CTE:** las consultas de verificación referenciaban los CTE `totales`
   y `prom`, que solo existen dentro de su propia sentencia → se reescribieron
   como subconsultas autocontenidas.

**Otra equivalencia verificada (espuria, Parte 1):** la consulta de la
competencia sin índice y con índice no devuelve iguales filas (el índice no
cambia el resultado: `SELECT ... EXCEPT SELECT ...` = 0 en ambas direcciones,
no se compara acá porque EXCEPT ignora orden; la verificación de orden quedó a
cargo del plan `ORDER BY precio, id`).