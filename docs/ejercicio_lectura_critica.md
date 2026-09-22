# Ejercicio de lectura crítica (TP2, Parte 3)

**Materia:** Base de Datos II — UTN · **Proyecto:** Food Store
**Ejercicio:** dos scripts SQL aparentemente simples pero peligrosos.
Para cada uno: **qué hace**, **por qué es peligroso**, **cómo se
corrige**. Cierre: patrón del error y cómo se relaciona con el
protocolo de seguridad y las reglas R4–R7.

---

## Script 1 — Baja masiva sin condición

### 1a. Qué hace

```sql
UPDATE funcion SET activa = FALSE;
```

Intento (según la consigna): *dar de baja las funciones de las
películas que se retiraron de cartel*. El entrenador lo escribió
creyendo que ese era el contexto implícito del UPDATE.

### 1b. Por qué es peligroso

1. **No tiene `WHERE`**: actualiza TODAS las filas de `funcion`, no
   solo las de películas retiradas. Si la tabla tiene 40.000 funciones,
   las 40.000 quedan con `activa = FALSE`.
2. **Destruye información histórica/presente**: mata también funciones
   futuras ya programadas y en cartel → el cine pierde la grilla; y
   funciones pasadas cuyas entradas ya se vendieron quedan marcadas
   "inactivas", cortando la trazabilidad de ventas (equivalente a romper
   R7 en nuestro esquema: nunca se pierde la historia).
3. **Sin protocolo**: si se ejecuta fuera de una transacción, cada fila
   se commitea sola y es **irreversible**. No hay `BEGIN/ROLLBACK` para
   revisar cuántas filas iba a tocar.

Esto es una variante del clásico *UPDATE sin WHERE*: el riesgo no está
en la sintaxis (válida) sino en la intención asumida que el motor no
puede adivinar.

### 1c. Cómo se corrige

Hay que **explicitar qué es "retirada de cartel"** y filtrar por eso:

```sql
BEGIN;

-- control ANTES de escribir: ¿cuáles y cuántas serían afectadas?
SELECT count(*) AS funciones_inactivas_objetivo
FROM funcion f
JOIN pelicula p ON p.id = f.pelicula_id
WHERE p.retirada_de_cartel = TRUE
  AND f.activa = TRUE;

-- el UPDATE, ahora SI filtrado por la condición
UPDATE funcion f
   SET activa = FALSE
WHERE f.pelicula_id IN (SELECT id FROM pelicula WHERE retirada_de_cartel = TRUE);

-- reviso el resultado antes de hacerlo definitivo
SELECT count(*) AS funciones_ahora_inactivas FROM funcion WHERE activa = FALSE;

COMMIT;   -- solo si los números son razonables; si no: ROLLBACK
```

Regla extra aplicable al proyecto Food Store: como la baja es lógica,
mantener un NULL/condición por fila y nunca borrar — y medir el alcance
con un `SELECT` del mismo `WHERE` **antes** del `UPDATE`.

---

## Script 2 — `DELETE` con la trampa del `NULL` en `NOT IN`

### 2a. Qué hace

```sql
DELETE FROM categoria WHERE id NOT IN (SELECT categoria_id FROM producto);
```

Intento: *borrar las categorías sin productos* (limpieza de datos
huerfanos).

### 2b. Por qué es peligroso

1. **La trampa del NULL en `NOT IN`.** Si `producto.categoria_id` puede
   ser NULL en el modelo (categoría opcional), la subconsulta devuelve
   un conjunto que **contiene NULL**. En lógica de tres valores, si
   `id NOT IN (..., NULL, ...)` → UNKNOWN → la condición es falsa para
   **todas** las categorías → el `DELETE` borra **cero filas**, sin
   error y sin aviso. El "borrado de categorías vacías" simplemente no
   ocurre y nadie lo nota.
2. **Borrado físico sobre una tabla maestra**: aunque no hubiera NULL y
   funcionara, elimina físicamente filas de `categoria`, una tabla con
   historial. En el proyecto Food Store esto viola R7 (sin borrados
   físicos de categorías). El dato muere para siempre.
3. **Carrera (concurrencia)**: entre la evaluación del `NOT IN` y el
   `DELETE` otra sesión puede insertar un producto en esa categoría
   aparentemente vacía → se destruye una categoría recién usada.

### 2c. Cómo se corrige

`NOT EXISTS` es inmune al NULL y refuerza la intención:

```sql
BEGIN;

-- control: categorías que quedarían marcadas (sin productos)
SELECT c.id, c.nombre
FROM categoria c
WHERE NOT EXISTS (SELECT 1 FROM producto p WHERE p.categoria_id = c.id);

-- baja lógica (recomendado, respeta R7)
UPDATE categoria c
   SET activo = FALSE
WHERE NOT EXISTS (SELECT 1 FROM producto p WHERE p.categoria_id = c.id);

-- si el negocio exigiera el borrado físico, al menos con NOT EXISTS
-- y dentro de la transacción:
-- DELETE FROM categoria c
--  WHERE NOT EXISTS (SELECT 1 FROM producto p WHERE p.categoria_id = c.id);

-- verificación del alcance antes de COMMIT
SELECT count(*) AS categorias_inactivas FROM categoria WHERE activo = FALSE;

COMMIT;   -- o ROLLBACK si el número no es el esperado
```

Notas de la corrección:

- `NOT EXISTS (SELECT 1 FROM producto p WHERE p.categoria_id = c.id)`
  **correlaciona** por la fila `c` y no tiene el problema de NULL.
- La transacción **y el re-chequeo en el mismo `WHERE`** cubren la
  carrera de la otras sesión (aunque para blindarla del todo se usaría
  `SELECT ... FOR UPDATE` de las filas de `categoria`, tema de la
  Parte 2).
- Bajar lógicamente con `activo = FALSE` (esquema Food Store) preserva
  la historia en lugar de destruirla.

---

## Cierre: patrón de error y vínculo con el protocolo

| Script | Patrón | Consecuencia si se ejecuta tal cual | Corrección |
|---|---|---|---|
| 1 | `UPDATE` sin `WHERE` (intención no expresada) | Toda la tabla inactivada; historia perdida; sin vuelta atrás | filtrar por la condición, control `SELECT` previo, `BEGIN/COMMIT` |
| 2 | `NOT IN` + subconsulta con NULL | Script silencioso: no borra nada; o borrado físico de maestras | `NOT EXISTS`, baja lógica, transacción con verificación |

Ambos se escribirían igual por un humano apurado que por una IA
(predicción plausible del "siguiente token" sin contexto); por eso el
mismo protocolo de la Parte 1 aplica aquí:

1. **Copia** – ejecutar siempre sobre `food_store_dev`.
2. **Transacción** – `BEGIN`, medir alcance (`SELECT` con el mismo
   `WHERE`), decidir, `COMMIT`/`ROLLBACK`.
3. **Respaldo** – `pg_dump` previo a cualquier operación masiva
   (`respaldos/`).

El motor nunca puede adivinar la intención: un `UPDATE`/`DELETE` sin
condición se ejecuta. La responsabilidad es de quien lo escribe, y la
evidencia de la Parte 1 (triggers + transacciones) son las defensas del
proyecto contra estos fallos.