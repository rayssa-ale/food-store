# Informe de laboratorio — Concurrencia (TP2, Parte 2)

**Materia:** Base de Datos II — UTN | **Proyecto:** Food Store
**Motor:** PostgreSQL 18 (local) · **Base de trabajo:** `food_store_dev`
(protocolo_seguridad.md: toda la actividad sobre la copia)

## Contexto y metodología

- **Sesiones:** dos conexiones concurrentes reales al motor
  (etiquetadas **A** y **B**), sobre las tablas `producto`, `pedido` y
  `detalle_pedido` con los datos de `seed.sql`.
- **MQVC / aislamiento:** PostgreSQL usa MVCC. El nivel por defecto es
  `READ COMMITTED` (nueva instantánea por **sentencia**); con
  `REPEATABLE READ` la instantánea se fija en la **primera sentencia**
  y se mantiene toda la transacción.
- **Objetivo:** reproducir 3+ anomalías de concurrencia (se hicieron 4),
  leer la explicación de la IA, y **verificarla contra el motor**,
  comparando el nivel de aislamiento que la corrige.

## Cuadro de la solución esperada (explicación a priori de la IA)

**Herramienta usada:** OpenCode (CLI de IA), asistente *big-pickle*.

> En PostgreSQL, `READ COMMITTED` toma una instantánea nueva por cada
> sentencia dentro de la transacción. Por eso la misma consulta ejecutada
> dos veces puede devolver resultados distintos si otra sesión committeó
> cambios entre medias: eso origina **lecturas no repetibles** (cambio de
> un valor en particular) y **lecturas fantasma** (cambio en el *set* de
> filas que matchea un COUNT/SUM). Con `REPEATABLE READ`, en cambio, la
> transacción queda anclada a una única instantánea tomada en su primera
> consulta, así que ambas anomalías desaparecen. Por otro lado, una
> escritura o un `SELECT ... FOR UPDATE` bloquea la fila hasta el COMMIT/
> ROLLBACK de su transacción: otra sesión que quiera `UPDATE` de la misma
> fila **espera**. Si dos sesiones se quedan esperando cada una por una
> fila que la otra retiene, se produce un **interbloqueo** que el motor
> detecta y resuelve abortando una de las transacciones (SQLSTATE 40P01).

| Escenario | Nivel que reproduce | Nivel que corrige | Mecanismo en PG |
|---|---|---|---|
| 1. Lectura no repetible | READ COMMITTED | REPEATABLE READ | instantánea fija |
| 2. Lectura fantasma | READ COMMITTED | REPEATABLE READ | instantánea fija |
| 3. Espera por bloqueo | cualquiera | `FOR UPDATE` previo + commit temprano | lock de fila |
| 4. Interbloqueo | 2 sesiones con locks cruzados | detector de interbloqueo | abort de una tx (40P01) |

---

## Escenario 1 — Lectura no repetible

### Cómo se reprodujo

| Sesión A | Sesión B |
|---|---|
| `BEGIN;` | |
| `SELECT precio FROM producto WHERE id=1;` → 1200.00 | |
| (idle) | `BEGIN;` |
| | `UPDATE producto SET precio=1300.00 WHERE id=1;` |
| | `COMMIT;` |
| `SELECT precio FROM producto WHERE id=1;` → ??? | |

### Salida real del motor (transcript)

```
[A] BEGIN (READ COMMITTED, por defecto)
[A] SELECT precio -> 1200.00
[B] UPDATE producto SET precio=1300 WHERE id=1
[B] COMMIT
[A] SELECT precio (de nuevo) -> 1300.00        ← CAMBIÓ
```

### Explicación de la IA

> La transacción A quedó en `READ COMMITTED`. Su primera lectura tomó
> una instantánea con 1200.00; la segunda, ejecutada después del COMMIT
> de B, tomó una instantánea nueva y vio 1300.00. Es la definición de
> lectura no repetible: el mismo SELECT, en la misma transacción, con
> dos resultados. La regla "precio congelado al facturar" (R4/R10) hace
> relevante esta anomalía: una facturación confiaría en el precio de una
> lectura anterior y se llevaría una sorpresa.

### Verificación en el motor

Se repitió el escenario cambiando el aislamiento de A a `REPEATABLE READ`:

```
[A] BEGIN + SET ISOLATION LEVEL REPEATABLE READ
[A] SELECT precio -> 1300.00
[B] UPDATE producto SET precio=1400 WHERE id=1
[B] COMMIT
[A] SELECT precio (de nuevo) -> 1300.00        ← ESTABLE
```

**Confirma la explicación:** con `REPEATABLE READ` la segunda lectura
sigue viendo la misma instantánea (1300.00) aunque B ya committeó 1400.00.

## Escenario 2 — Lectura fantasma

### Cómo se reprodujo

| Sesión A | Sesión B |
|---|---|
| `BEGIN;` | |
| `SELECT count(*) FROM detalle_pedido WHERE pedido_id=1;` → 2 | |
| (idle) | `BEGIN;` |
| | `INSERT INTO detalle_pedido (pedido_id, producto_id, ...) VALUES (1, 5, 1, 500.00);` |
| | `COMMIT;` |
| `SELECT count(*) FROM detalle_pedido WHERE pedido_id=1;` → ??? | |

### Salida real del motor

```
[A] SELECT count(*) lineas pedido 1 -> 2
[B] INSERT detalle (pedido 1, producto 5)
[B] COMMIT
[A] SELECT count(*) (de nuevo) -> 3            ← línea "fantasma"
```

### Explicación de la IA

> A cuenta las líneas del pedido 1 y obtiene 2. B inserta una línea
> nueva y committea. La segunda cuenta de A, al tomar una instantánea
> fresca en READ COMMITTED, incluye la fila recién creada: 3. La fila
> "aparece" en mitad de la transacción de A: es una lectura fantasma.
> El riesgo concreto: A podría estar recalculando el total del pedido
> (SUM) para confirmar el cobro y el resultado cambia de una consulta a
> la otra.

### Verificación en el motor

Con A en `REPEATABLE READ`, el mismo COUNT no incorpora la fila de B:

```
[A] SELECT count(*) lineas pedido 1 -> 3
[B] INSERT detalle (pedido 1, producto 3)
[B] COMMIT
[A] SELECT count(*) (de nuevo) -> 3            ← ESTABLE
```

**Confirma la explicación:** por MVCC, PostgreSQL también evita las
lecturas fantasma con `REPEATABLE READ` (a diferencia del estándar ANSI,
que la prevé solo en SERIALIZABLE).

## Escenario 3 — Espera por bloqueo (`SELECT ... FOR UPDATE`)

### Cómo se reprodujo

| Sesión A | Sesión B |
|---|---|
| `BEGIN;` | |
| `SELECT stock FROM producto WHERE id=6 FOR UPDATE;` → 12 | (inicia +2,5 s) |
| (tiene el lock ~4,5 s) | `BEGIN; UPDATE producto SET stock=stock WHERE id=6;` → **se bloquea** |
| `COMMIT;` (libera) | → desbloqueado, continúa |
| | `COMMIT;` |

### Salida real del motor (con tiempos reales)

```
[A] SELECT stock ... id=6 FOR UPDATE (bloqueo adquirido)
[A] sigo con el lock...
[A] COMMIT (libera el lock)
[B] UPDATE producto id=6 -> DESBLOQUEADO, esperó 4.51s
[B] COMMIT
```

### Explicación de la IA

> `SELECT ... FOR UPDATE` toma un lock de exclusión sobre la fila. B,
> al intentar actualizar la misma fila, queda encolada detrás de A hasta
> el COMMIT de A (4,51 s en la medición). Es el mecanismo que evita la
> **sobreventa**: si dos cajeros vendieran el mismo producto, la segunda
> venta debe esperar a que la primera decida y, al recién liberarse el
> lock, el stock leído ya refleja la primera venta.

### Verificación en el motor

El `UPDATE` de B retornó recién **después** del COMMIT de A (4,51 s de
espera medida). La fila se desbloquea y la operación completó sin
perder datos. Coincide con la explicación. Este mismo `FOR UPDATE`
implícito se usa en el trigger R9 (`UPDATE producto ... WHERE
stock >= cantidad`) para serializar ventas.

## Escenario 4 — Interbloqueo (deadlock, SQLSTATE 40P01)

### Cómo se reprodujo

Ambas sesiones adquieren locks en **orden inverso**:

| Sesión A | Sesión B |
|---|---|
| `BEGIN;` | (inicia +1 s) `BEGIN;` |
| `SELECT ... FROM producto WHERE id=1 FOR UPDATE;` | `SELECT ... FROM producto WHERE id=4 FOR UPDATE;` |
| (espera 3 s) `SELECT ... FROM producto WHERE id=4 FOR UPDATE;` → **espera a B** | (espera 3 s) `SELECT ... FROM producto WHERE id=1 FOR UPDATE;` → **espera a A** |

Ninguna puede avanzar: **interbloqueo**.

### Salida real del motor

```
[D:A] BEGIN
[D:A] LOCK producto 1
[D:B] BEGIN
[D:B] LOCK producto 4
[D:A] ABORTADO -> DeadlockDetected sqlstate=40P01
[D:B] LOCK producto 1
[D:B] COMMIT (termine)
```

### Explicación de la IA

> A retiene el producto 1 y pide el 4; B retiene el producto 4 y pide el
> 1. Cada una espera el lock que la otra tiene: un ciclo de espera sin
> salida. PostgreSQL detecta el ciclo con su deadlock detector y aborta
> una de las transacciones con SQLSTATE **40P01** (DeadlockDetected),
> dejando que la otra termine. La transacción abortada debe reemitirse
> (retry) por la sesión que la originó — es la estrategia estándar.

### Verificación en el motor

El transcript muestra exactamente lo predicho: la sesión A fue abortada
por el motor con `sqlstate=40P01` y la sesión B completó su trabajo y
committeó. **Confirmado en el motor.**

---

## Síntesis

| Escenario | Anomalía observada | Solución/estado correcto | Evidencia |
|---|---|---|---|
| 1. Lectura no repetible | 1200.00 → 1300.00 | `REPEATABLE READ`: estable | transcript RC vs RR |
| 2. Lectura fantasma | COUNT 2 → 3 | `REPEATABLE READ`: estable | transcript RC vs RR |
| 3. Espera por bloqueo | B esperó 4,51 s | `FOR UPDATE` + COMMIT temprano | tiempos reales |
| 4. Interbloqueo | ciclo A↔B | detector del motor: 40P01 | sqlstate capturado |

**Decisiones tomadas:**

1. En los flujos de facturación (leer precio + sumar líneas) usar
   `REPEATABLE READ` para que el "precio congelado" (R4/R10) sea
   perceptivamente correcto al momento de cobrar.
2. Para inventario (R9) mantener el `UPDATE ... WHERE stock >= cantidad`
   que ya serializa por fila; nada de `SELECT` puro + UPDATE por arriba.
3. Ante 40P01, releer el estado y reemitir la transacción abortada.
4. Todo se trabajó sobre la copia `food_store_dev`, en sesiones de
   prueba; los datos quedaron consistentes al final del lab
   (precio=1200.00, stock p6=12, 2 líneas en pedido 1).