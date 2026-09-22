# FOOD STORE — TP4 Parte 3: Equivalencia de consultas con EXCEPT

DB de laboratorio: **food_store_tp3** (50.006 productos, 20.003 clientes,
200.003 pedidos, 500.014 líneas). Todas las corridas sobre la copia de
trabajo, servidor caliente, PostgreSQL 18.

Nota metodológica: `EXCEPT` es una operación de CONJUNTO sobre la tupla
completa (en este caso tuplas con texto/numérico, comparables sin ambigüedad).
`A - B` da 0 filas implica que todo resultado de A está en B; `B - A` da 0
implica que todo resultado de B está en A; juntos prueban que los conjuntos
de resultados son idénticos.

---

## ESPEC (a) — Ranking con función de ventana

**Enunciado preciso.** *"Para cada cliente con al menos un pedido ENTREGADO,
mostrar apellido, nombre, email, el total gastado (suma de `cantidad *
precio_unitario` de las líneas de sus pedidos ENTREGADO) y su puesto en un
ranking de mayor a menor gasto. Los que empatan en gasto comparten puesto y
los siguientes quedan saltados (RANK clásico). Orden final por puesto y por
id ascendente. No usar `SELECT *`."*

**Dato de entrada.** 19.882 clientes cumplen la condición (tienen ≥1 pedido
ENTREGADO).

### Versión (A) — generada por IA, con `RANK() OVER`

```sql
SELECT apellido, nombre, email, total,
       RANK() OVER (ORDER BY total DESC) AS puesto
FROM totales;
```

### Intento (B₁) — "RANK sin ventana" con `COUNT(DISTINCT)` (NO equivalía)

```sql
SELECT apellido, nombre, email, total,
       1 + (SELECT COUNT(DISTINCT t2.total)
            FROM totales t2 WHERE t2.total > t.total) AS puesto
FROM totales t;
```

**Error destapado por EXCEPT.** `A - B₁ = 19.743` filas (y por simetría
`B₁ - A = 19.743`). La causa es semántica: `RANK` cuenta **filas** con valor
mayor (los empates comparten puesto porque ninguno es "mayor"), mientras
`COUNT(DISTINCT total)` cuenta **valores** distintos, que es exactamente la
definición de `DENSE_RANK`. Con 19.882 clientes y pocos miles de totales
distintos (muchas sumas repetidas), casi todas las filas quedaban con un
puesto menor en B₁. El mecanismo de verificación (no la relectura) dejó en
evidencia que la "alternativa sin ventana" no era equivalente.

### Versión (B) corregida — con `COUNT(*)` de filas mayores (equivalente)

```sql
SELECT apellido, nombre, email, total,
       1 + (SELECT COUNT(*)
            FROM totales t2 WHERE t2.total > t.total) AS puesto
FROM totales t;
```

### Verificación con EXCEPT (corrida definitiva)

| Chequeo            | Filas |
|--------------------|------:|
| `filas_A`          | 19.882 |
| `filas_B`          | 19.882 |
| `especA_A - B`     | **0** |
| `especA_B - A`     | **0** |

La versión corregida usa la definición clásica de RANK por conteo de filas
estrictamente mayores; la verificación confirma igualdad de conjuntos en
ambas direcciones.

---

## ESPEC (b) — Subconsulta correlacionada

**Enunciado preciso.** *"Para cada producto vigente, mostrar id, nombre,
precio y un indicador SÍ/NO de si su precio es MAYOR que el promedio de los
precios de los productos vigentes de su propia categoría. No usar
`SELECT *`."*

**Dato de entrada.** 50.006 productos, todos vigentes, repartidos en 3
categorías.

### Versión (A) — generada por IA, subconsulta escalar correlacionada

```sql
SELECT p.id, p.nombre, p.precio,
       CASE WHEN p.precio > (SELECT AVG(p2.precio)
                             FROM producto p2
                             WHERE p2.categoria_id = p.categoria_id
                               AND p2.activo)
            THEN 'SI' ELSE 'NO' END AS sobre_promedio
FROM producto p
WHERE p.activo;
```

### Versión (B) — alternativa: `AVG OVER` con partición por categoría

```sql
SELECT id, nombre, precio,
       CASE WHEN precio > AVG(precio) OVER (PARTITION BY categoria_id)
            THEN 'SI' ELSE 'NO' END AS sobre_promedio
FROM producto p
WHERE activo;
```

Ambas computan el mismo promedio por categoría (identidad
`AVG(...) OVER (PARTITION BY categoria_id)` ≡ promedio del grupo de la
subconsulta correlacionada, dado que la partición se define exactamente por
`categoria_id` y el filtro `activo` es el mismo en ambos lados).

### Verificación con EXCEPT (corrida definitiva)

| Chequeo                | Valor |
|------------------------|------:|
| `filas_A` / `filas_B`  | 50.006 / 50.006 |
| `si_A` / `si_B`        | 25.046 / 25.046 |
| `especB_A - B`         | **0** |
| `especB_B - A`         | **0** |

---

## Conclusión

- La especificación (a) entregó **un caso real de inconsistencia semántica
  detectado por EXCEPT**: la versión "artesanal" con `COUNT(DISTINCT total)`
  implementaba `DENSE_RANK`, no `RANK`. El conteo directo de filas con
  `COUNT(*)` sí es equivalente y quedó verificado 0/0 en ambas direcciones.
- La especificación (b) fue equivalente desde el primer intento (0/0 en
  ambas direcciones), confirmando que `AVG OVER (PARTITION BY ...)` y la
  subconsulta escalar correlacionada por el mismo grupo producen resultados
  idénticos también en un conjunto de 50.006 filas.
- En todos los casos la verificación se hizo contra el conjunto completo de
  resultados (no muestras), por lo que el criterio vale sin suposiciones
  estadísticas.

Script de verificación: `sql/equivalencias_tp4.sql` (reproducible sobre
food_store_tp3).