# Verificación de equivalencia — Parte D

**Trabajo Práctico Unidad 5 · Base de Datos II**
Protección de datos personales: anonimización y verificación de equivalencia.

---

## 1. Objetivo

Construir `public.usuario_anon` como una copia **anonimizada, determinista y de solo agregados útiles** de `public.usuario`, y demostrar con evidencia ejecutada que la consulta “cantidad de usuarios por rol y por mes de alta” produce resultados **idénticos** sobre ambas tablas, sin que la tabla anonimizada permita recuperar identidad, contacto, credenciales ni combinaciones reidentificadoras.

---

## 2. Entorno y base utilizada

| Ítem | Valor verificado |
|---|---|
| Repositorio | `C:\BD\food-store\TP7` |
| Motor | `PostgreSQL 17.11 on x86_64-windows, compiled by msvc-19.44.35228, 64-bit` |
| Base usada | `foodstore_test` |
| Decisión de base | `food_Store` existe pero tiene **0 filas** en `usuario`; `foodstore_test` tiene **20.000**. Se usa `foodstore_test` y se deja constancia. |
| Conexión | `psql -h 127.0.0.1 -U postgres -d foodstore_test` (binario en `C:\Users\julic\OneDrive\Desktop\Nueva carpeta\bin\psql.exe`) |
| TimeZone de sesión | `America/Buenos_Aires` |
| Script | `sql/usuario_anon.sql` |
| Tabla escrita | únicamente `public.usuario_anon` |

Comando base de todas las capturas:

```bash
psql -h 127.0.0.1 -U postgres -d foodstore_test -v ON_ERROR_STOP=1 -P pager=off -c "..."
```

Las credenciales no se registran en archivos.

### Estado verificado de `public.usuario`

```sql
SELECT count(*) AS total,
       count(*) FILTER (WHERE eliminado)    AS eliminados,
       count(*) FILTER (WHERE mail IS NULL) AS mail_null,
       count(DISTINCT created_at)           AS created_distintos,
       min(id) AS min_id, max(id) AS max_id,
       min(created_at) AS min_created, max(created_at) AS max_created
FROM public.usuario;
```

```text
 total | eliminados | mail_null | created_distintos | min_id | max_id |           min_created           |           max_created
-------+------------+-----------+-------------------+--------+--------+---------------------------------+---------------------------------
 20000 |          0 |         0 |                 1 |      1 |  20000 | 2026-09-07 21:25:22.882655-03 | 2026-09-07 21:25:22.882655-03
```

```sql
SELECT rol, count(*) FROM public.usuario GROUP BY rol;
```

```text
   rol   | count
---------+-------
 USUARIO | 20000
```

**Hallazgo:** el enum `rol` admite `ADMIN` y `USUARIO`, pero los datos actuales solo contienen `USUARIO`. **El agrupamiento por mes es degenerado**: existe un único `created_at` para las 20.000 filas.

Esquema de origen (relevante):

```text
id         bigint  NOT NULL  identity  PK
nombre     varchar(80)  NOT NULL
apellido   varchar(80)  NOT NULL
mail       varchar(120) NOT NULL  UNIQUE
celular    varchar(30)  NULL
contrasena varchar(255) NOT NULL
rol        rol          NOT NULL  DEFAULT 'USUARIO'
eliminado  boolean      NOT NULL  DEFAULT false
created_at timestamptz  NOT NULL  DEFAULT now()
```

---

## 3. Patrón de anonimización, campo por campo

| Campo | Valor en `usuario_anon` | Motivo / decisión |
|---|---|---|
| `id` | **se conserva** | Clave primaria. Es un **cuasi-identificador interno**: se documenta como tal. Permite control de integridad y comparaciones por `id % 10`. |
| `nombre` | `'Usuario ' \|\| id` | Sintético, determinista, **no derivado** del nombre real (no es hash ni enmascarado reversible). |
| `apellido` | `'Anonimo'` | Constante. Elimina el apellido real por completo. |
| `mail` | `'user' \|\| id \|\| '@anon.invalid'` | Dominio reservado `.invalid`: nunca resoluble. Preserva **unicidad** 1:1 con `id`. No se copia ni transforma el mail real. |
| `celular` | `NULL` | Se elimina el dato. La columna sigue siendo nullable como en el origen (nulabilidad equivalente). En el origen hay 0 nulos, pero el tipo lo permite. |
| `contrasena` | `'ANONIMIZADO'` | Marcador fijo. **Nunca** se copian hashes ni contraseñas reales. |
| `rol` | **se conserva**, tipo `public.rol` | Se mantiene el **enum**, no `text`, para que el agrupamiento sea comparable y del mismo tipo. |
| `eliminado` | **se conserva** | Permite aplicar el **mismo filtro** en ambas consultas. Hoy 0 filas con `true`. |
| `created_at` | `date_trunc('month', created_at)` | Granularidad mensual solicitada. Reduce precisión temporal y evita usar la hora exacta de alta como identificador. |

Decisiones explícitas:

- **Sin funciones volátiles:** el script no usa `random()`, `now()` ni `gen_random_uuid()`. Verificable por lectura: los únicos valores son constantes o dependen de `id`.
- **Sin hashes del dato real:** no hay `md5`/`sha`/`crypt` sobre columnas personales; un hash de un dato de baja entropía (teléfono, mail) sería reversible por diccionario.
- **`created_at` truncado a mes:** se eligió esa granularidad porque es la que pide la consigna y porque el análisis de “altas por mes” no necesita día ni hora. El truncado además es **idempotente**, lo que permite aplicar `date_trunc('month', ...)` también sobre `usuario_anon` sin alterar el resultado.
- **`id` conservado:** necesario como PK y para el control de equivalencia. Se asume el riesgo de enlace por `id` (ver Limitaciones).

---

## 4. Script ejecutable

Archivo: `sql/usuario_anon.sql`

Características:

- Encabezado en español con el estilo de `sql/simulacro_incidente.sql` (nombre de archivo, parte, base objetivo, bloques separados).
- Transacción única: `BEGIN` → `CREATE TABLE IF NOT EXISTS` → `TRUNCATE` → `INSERT ... SELECT` → `REVOKE` → `COMMIT`.
- `rol` con el enum `public.rol`.
- `PRIMARY KEY (id)` y nulabilidad equivalente a las columnas conservadas.
- `REVOKE ALL ON public.usuario_anon FROM PUBLIC;` (sin crear roles).
- `COMMENT ON` de tabla y de las columnas cuasi-identificadoras.
- Verificación final: total de filas y mails duplicados.
- Solo lee `public.usuario` (`SELECT ... FROM public.usuario`); no la modifica.

### Ejecución 1

```text
BEGIN
CREATE TABLE
TRUNCATE TABLE
INSERT 0 20000
REVOKE
COMMIT
            etapa             | total
------------------------------+-------
 usuario_anon: filas cargadas | 20000
(1 row)

             etapa              | duplicados
--------------------------------+------------
 usuario_anon: mails duplicados |          0
(1 row)
```

### Ejecución 2 (idempotencia)

```text
BEGIN
NOTICE:  la relación «usuario_anon» ya existe, omitiendo
CREATE TABLE
TRUNCATE TABLE
INSERT 0 20000
REVOKE
COMMIT
            etapa             | total
------------------------------+-------
 usuario_anon: filas cargadas | 20000
(1 row)

             etapa              | duplicados
--------------------------------+------------
 usuario_anon: mails duplicados |          0
(1 row)
```

**Resultado:** corre dos veces seguidas sin error (`ON_ERROR_STOP=1`). El `NOTICE` es informativo, no un error.

Tipos y nulabilidad resultantes:

```sql
SELECT attname, format_type(atttypid, atttypmod) AS tipo, attnotnull
FROM pg_attribute
WHERE attrelid = 'public.usuario_anon'::regclass AND attnum > 0
ORDER BY attnum;
```

```text
  attname   |           tipo           | attnotnull
------------+--------------------------+------------
 id         | bigint                   | t
 nombre     | character varying(80)    | t
 apellido   | character varying(80)    | t
 mail       | character varying(120)   | t
 celular    | character varying(30)    | f
 contrasena | character varying(255)   | t
 rol        | rol                      | t
 eliminado  | boolean                  | t
 created_at | timestamp with time zone | t
```

Muestra de la tabla anonimizada (solo valores sintéticos):

```sql
SELECT id, nombre, apellido, mail, celular, contrasena, rol, eliminado, created_at
FROM public.usuario_anon ORDER BY id LIMIT 3;
```

```text
 id |  nombre   | apellido |        mail        | celular | contrasena  |   rol   | eliminado |       created_at
----+-----------+----------+--------------------+---------+-------------+---------+-----------+------------------------
  1 | Usuario 1 | Anonimo  | user1@anon.invalid |         | ANONIMIZADO | USUARIO | f         | 2026-09-01 00:00:00-03
  2 | Usuario 2 | Anonimo  | user2@anon.invalid |         | ANONIMIZADO | USUARIO | f         | 2026-09-01 00:00:00-03
  3 | Usuario 3 | Anonimo  | user3@anon.invalid |         | ANONIMIZADO | USUARIO | f         | 2026-09-01 00:00:00-03
```

Restricción de acceso verificada:

```sql
SELECT relacl FROM pg_class WHERE oid = 'public.usuario_anon'::regclass;
```

```text
            relacl
------------------------------
 {postgres=arwdDxtm/postgres}
```

No aparece `=r/...` (entrada de `PUBLIC`): el `REVOKE` quedó aplicado.

---

## 5. Especificación y prompt enviado a OpenCode

### 5.1 Especificación redactada por el equipo (antes de pedir nada)

- **Métrica:** cantidad de usuarios.
- **Dimensiones:** `rol` y mes de alta.
- **Columna temporal:** `created_at`.
- **Granularidad:** `date_trunc('month', created_at)`.
- **Filtro:** `eliminado = false`, idéntico en ambas versiones.
- **`TimeZone`:** `America/Buenos_Aires`.
- **Salida:** `rol`, `mes_alta`, `cantidad_usuarios`.
- **Orden:** `ORDER BY rol, mes_alta`.
- **Prohibido:** `SELECT *`, columnas identificables (`mail`, `nombre`, `apellido`, `celular`, `contrasena`), funciones volátiles, DDL/DML en la respuesta.
- **Requisito de comparabilidad:** misma semántica exacta en las dos consultas.

### 5.2 Prompt exacto

```text
Necesito dos consultas SQL para PostgreSQL 17 sobre la base foodstore_test con TimeZone America/Buenos_Aires.

Objetivo: "cantidad de usuarios por rol y por mes de alta".

Requisitos estrictos:
- Primera consulta: sobre public.usuario_anon.
- Segunda consulta: equivalente sobre public.usuario.
- Misma semántica en ambas: idénticos filtros, granularidad temporal, TimeZone y ORDER BY.
- Columna temporal: created_at.
- Granularidad: date_trunc('month', created_at).
- Considerar eliminado con el mismo filtro explícito en ambas.
- Columnas de salida sin datos identificables: solo rol, mes_alta y cantidad_usuarios.
- Sin SELECT *, sin mail/nombre/apellido/celular/contrasena.
- Sin now(), random() ni gen_random_uuid().
- Agregación con COUNT(*).
- ORDER BY determinista: rol, mes_alta.
- Entregar ambas consultas por separado, claramente etiquetadas.
- Solo SELECT agregados; sin DDL ni DML.

Contexto: usuario_anon ya tiene created_at truncado a mes; usuario tiene el timestamp completo.
```

### 5.3 Respuesta del asistente (resumen)

OpenCode devolvió dos `SELECT` agregados con la misma estructura:

```sql
SELECT rol,
       date_trunc('month', created_at) AS mes_alta,
       COUNT(*) AS cantidad_usuarios
FROM public.usuario_anon
WHERE eliminado = false
GROUP BY rol, date_trunc('month', created_at)
ORDER BY rol, mes_alta;
```

```sql
SELECT rol,
       date_trunc('month', created_at) AS mes_alta,
       COUNT(*) AS cantidad_usuarios
FROM public.usuario
WHERE eliminado = false
GROUP BY rol, date_trunc('month', created_at)
ORDER BY rol, mes_alta;
```

### 5.4 Validación humana y correcciones

| Chequeo | Resultado |
|---|---|
| ¿`SELECT *`? | No |
| ¿Columnas identificables? | No: solo `rol`, `mes_alta`, `cantidad_usuarios` |
| ¿`now()` / `random()`? | No |
| ¿Mismo filtro `eliminado = false`? | Sí, idéntico |
| ¿Misma granularidad? | Sí, `date_trunc('month', created_at)` en ambas |
| ¿Mismo `ORDER BY`? | Sí, `rol, mes_alta` |
| ¿Solo agregados? | Sí, `COUNT(*)` |

**Errores reales del asistente detectados y corregidos:**

1. **Distribución inventada.** El borrador del informe afirmaba `ADMIN 10.000 / USUARIO 10.000` (2 filas) sin haber ejecutado la consulta. La ejecución real devolvió **`USUARIO` 20.000 (1 fila)**. Se descartaron las salidas supuestas y se reemplazaron por las capturas reales.
2. **Suposición sobre `ADMIN`.** El asistente asumió que existían usuarios `ADMIN` porque el enum los admite. El dato real muestra 0 `ADMIN`. Se documentó la diferencia entre el dominio del tipo y la distribución observada.
3. **Comandos incompatibles con el shell.** En las primeras capturas el asistente intentó usar `head`, `tail` y `grep` en PowerShell, lo que falló. Se corrigió usando `Select-Object` (y las herramientas de lectura de archivos).

Ninguna de estas imprecisiones llegó al informe final ni a la bitácora sin corrección.

---

## 6. D3 — Consultas ejecutadas y evidencia

Todas las consultas se ejecutaron en sesiones `psql` con `SET timezone = 'America/Buenos_Aires'` y el mismo `ORDER BY`.

```sql
SET timezone = 'America/Buenos_Aires';
SELECT current_setting('TimeZone') AS tz_sesion, version() AS motor;
```

```text
      tz_sesion       |                                  motor
----------------------+--------------------------------------------------------------------------
 America/Buenos_Aires | PostgreSQL 17.11 on x86_64-windows, compiled by msvc-19.44.35228, 64-bit
```

### 6.1 Totales de filas

```sql
SELECT (SELECT count(*) FROM public.usuario)      AS filas_usuario,
       (SELECT count(*) FROM public.usuario_anon) AS filas_usuario_anon;
```

```text
 filas_usuario | filas_usuario_anon
---------------+--------------------
         20000 |              20000
```

### 6.2 Consulta principal — `usuario_anon`

```sql
SELECT rol,
       date_trunc('month', created_at) AS mes_alta,
       COUNT(*) AS cantidad_usuarios
FROM public.usuario_anon
WHERE eliminado = false
GROUP BY rol, date_trunc('month', created_at)
ORDER BY rol, mes_alta;
```

```text
   rol   |        mes_alta        | cantidad_usuarios
---------+------------------------+-------------------
 USUARIO | 2026-09-01 00:00:00-03 |             20000
(1 row)
```

### 6.3 Consulta principal — `usuario` real

```sql
SELECT rol,
       date_trunc('month', created_at) AS mes_alta,
       COUNT(*) AS cantidad_usuarios
FROM public.usuario
WHERE eliminado = false
GROUP BY rol, date_trunc('month', created_at)
ORDER BY rol, mes_alta;
```

```text
   rol   |        mes_alta        | cantidad_usuarios
---------+------------------------+-------------------
 USUARIO | 2026-09-01 00:00:00-03 |             20000
(1 row)
```

### 6.4 Salidas lado a lado

| `rol` | `mes_alta` | `cantidad_usuarios` (anon) | `cantidad_usuarios` (real) |
|---|---|---|---|
| USUARIO | 2026-09-01 00:00:00-03 | 20000 | 20000 |

El mes mostrado es `2026-09-01 00:00:00-03` porque `date_trunc('month', ...)` lleva al día 1; el `created_at` real es `2026-09-07 21:25:22.882655-03`.

### 6.5 Consulta de control (mayor cardinalidad) — `usuario_anon`

```sql
SELECT rol,
       (id % 10) AS grupo_id_mod10,
       COUNT(*) AS cantidad_usuarios
FROM public.usuario_anon
WHERE eliminado = false
GROUP BY rol, (id % 10)
ORDER BY rol, grupo_id_mod10;
```

```text
   rol   | grupo_id_mod10 | cantidad_usuarios
---------+----------------+-------------------
 USUARIO |              0 |              2000
 USUARIO |              1 |              2000
 USUARIO |              2 |              2000
 USUARIO |              3 |              2000
 USUARIO |              4 |              2000
 USUARIO |              5 |              2000
 USUARIO |              6 |              2000
 USUARIO |              7 |              2000
 USUARIO |              8 |              2000
 USUARIO |              9 |              2000
(10 rows)
```

### 6.6 Consulta de control — `usuario` real

```sql
SELECT rol,
       (id % 10) AS grupo_id_mod10,
       COUNT(*) AS cantidad_usuarios
FROM public.usuario
WHERE eliminado = false
GROUP BY rol, (id % 10)
ORDER BY rol, grupo_id_mod10;
```

```text
   rol   | grupo_id_mod10 | cantidad_usuarios
---------+----------------+-------------------
 USUARIO |              0 |              2000
 USUARIO |              1 |              2000
 USUARIO |              2 |              2000
 USUARIO |              3 |              2000
 USUARIO |              4 |              2000
 USUARIO |              5 |              2000
 USUARIO |              6 |              2000
 USUARIO |              7 |              2000
 USUARIO |              8 |              2000
 USUARIO |              9 |              2000
(10 rows)
```

### 6.7 Control lado a lado

| `rol` | `id % 10` | cantidad (anon) | cantidad (real) |
|---|---|---|---|
| USUARIO | 0 | 2000 | 2000 |
| USUARIO | 1 | 2000 | 2000 |
| USUARIO | 2 | 2000 | 2000 |
| USUARIO | 3 | 2000 | 2000 |
| USUARIO | 4 | 2000 | 2000 |
| USUARIO | 5 | 2000 | 2000 |
| USUARIO | 6 | 2000 | 2000 |
| USUARIO | 7 | 2000 | 2000 |
| USUARIO | 8 | 2000 | 2000 |
| USUARIO | 9 | 2000 | 2000 |

**Nota:** el agrupamiento mensual es degenerado con estos datos (un solo mes). El control `rol, (id % 10)` aporta 10 grupos y demuestra la equivalencia con mayor cardinalidad.

---

## 7. Pruebas de equivalencia fuerte

### 7.1 Diferencia simétrica — rol / mes

```sql
(SELECT rol, date_trunc('month', created_at) AS mes_alta, COUNT(*) AS cantidad_usuarios
 FROM public.usuario
 WHERE eliminado = false
 GROUP BY rol, date_trunc('month', created_at)
 EXCEPT
 SELECT rol, date_trunc('month', created_at) AS mes_alta, COUNT(*) AS cantidad_usuarios
 FROM public.usuario_anon
 WHERE eliminado = false
 GROUP BY rol, date_trunc('month', created_at))
UNION ALL
(SELECT rol, date_trunc('month', created_at) AS mes_alta, COUNT(*) AS cantidad_usuarios
 FROM public.usuario_anon
 WHERE eliminado = false
 GROUP BY rol, date_trunc('month', created_at)
 EXCEPT
 SELECT rol, date_trunc('month', created_at) AS mes_alta, COUNT(*) AS cantidad_usuarios
 FROM public.usuario
 WHERE eliminado = false
 GROUP BY rol, date_trunc('month', created_at));
```

```text
 rol | mes_alta | cantidad_usuarios
-----+----------+-------------------
(0 rows)
```

### 7.2 Diferencia simétrica — control `rol, id % 10`

```sql
(SELECT rol, (id % 10) AS g, COUNT(*) AS c FROM public.usuario
 WHERE eliminado = false GROUP BY rol, (id % 10)
 EXCEPT
 SELECT rol, (id % 10) AS g, COUNT(*) AS c FROM public.usuario_anon
 WHERE eliminado = false GROUP BY rol, (id % 10))
UNION ALL
(SELECT rol, (id % 10) AS g, COUNT(*) AS c FROM public.usuario_anon
 WHERE eliminado = false GROUP BY rol, (id % 10)
 EXCEPT
 SELECT rol, (id % 10) AS g, COUNT(*) AS c FROM public.usuario
 WHERE eliminado = false GROUP BY rol, (id % 10));
```

```text
 rol | g | c
-----+---+---
(0 rows)
```

**Resultado:** 0 filas en ambas direcciones, para la consulta principal y para el control. La equivalencia no es solo visual.

---

## 8. Pruebas de no-fuga

Todas son `COUNT(*)` sobre joins; no se imprime ningún dato personal.

```sql
SELECT count(*) AS coincidencias_mail
FROM public.usuario u JOIN public.usuario_anon ua ON u.mail = ua.mail;

SELECT count(*) AS coincidencias_nombre_apellido
FROM public.usuario u JOIN public.usuario_anon ua
  ON (u.nombre || ' ' || u.apellido) = (ua.nombre || ' ' || ua.apellido);

SELECT count(*) AS coincidencias_celular
FROM public.usuario u JOIN public.usuario_anon ua ON u.celular = ua.celular
WHERE u.celular IS NOT NULL;

SELECT count(*) AS coincidencias_contrasena
FROM public.usuario u JOIN public.usuario_anon ua ON u.contrasena = ua.contrasena;
```

```text
 coincidencias_mail
--------------------
                  0
(1 row)

 coincidencias_nombre_apellido
-------------------------------
                             0
(1 row)

 coincidencias_celular
-----------------------
                     0
(1 row)

 coincidencias_contrasena
--------------------------
                        0
(1 row)
```

Verificación complementaria: `SELECT DISTINCT contrasena FROM usuario_anon;` devuelve un único valor, `ANONIMIZADO`, y `count(*) WHERE celular IS NOT NULL` devuelve `0`. No hay hashes reales ni datos de contacto.

| Prueba | Coincidencias |
|---|---|
| `mail` | **0** |
| `nombre` + `apellido` | **0** |
| `celular` | **0** |
| `contrasena` | **0** |

---

## 9. Determinismo

Checksum pedido por la consigna:

```sql
SELECT md5(string_agg(id::text || '|' || mail || '|' || nombre, ',' ORDER BY id)) AS checksum
FROM public.usuario_anon;
```

| Ejecución | Checksum |
|---|---|
| 1 | `703bd7edc6d5523f3093595e59ef90eb` |
| 2 (tras reejecutar `sql/usuario_anon.sql`) | `703bd7edc6d5523f3093595e59ef90eb` |

Checksum ampliado (incluye `created_at`, para cubrir también el truncado mensual):

```sql
SELECT md5(string_agg(id::text || '|' || mail || '|' || nombre || '|' || created_at::text, ',' ORDER BY id))
FROM public.usuario_anon;
```

| Ejecución | Checksum ampliado |
|---|---|
| 1 | `baa2c61dac3364ae95be9748194c2e6c` |
| 2 (tras reejecutar el script) | `baa2c61dac3364ae95be9748194c2e6c` |

**Resultado:** idénticos en ambas ejecuciones. El script es determinista y reejecutable.

---

## 10. Integridad de `usuario` y alcance de escritura

- El script contiene una sola referencia a `public.usuario`, dentro de `SELECT ... FROM public.usuario`. No hay `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE` ni `ALTER` sobre ella.
- Checksum de integridad de `usuario` medido antes y después de las reejecuciones finales:

```sql
SELECT md5(string_agg(id::text || '|' || mail, ',' ORDER BY id)) AS checksum, count(*) AS total
FROM public.usuario;
```

```text
             checksum             | total
----------------------------------+-------
 92090f15a97a12ea61e2c05f5a23a593 | 20000
```

Idéntico en ambas mediciones y total sin cambios: **`usuario` quedó intacta**.

- No se modificaron `sql/roles.sql`, `sql/simulacro_incidente.sql`, `docs/informe_auditoria.md`, `docs/log_auditoria_prueba.txt` ni ningún artefacto de las Partes A, B o C.

---

## 11. Limitaciones

1. **Mes degenerado.** Las 20.000 filas comparten un único `created_at` (`2026-09-07 21:25:22.882655-03`). El agrupamiento mensual produce un solo grupo, por lo que se agregó el control por `rol, (id % 10)`.
2. **`id` y `mes_alta` son cuasi-identificadores.** `id` se conserva como PK y el mail sintético se deriva de él; el mes conserva información temporal. Un enlace con datos externos por `id` sigue siendo posible por diseño. No se eliminó el riesgo de enlace, solo el de contenido personal.
3. **El mail sintético es un pseudónimo determinista de `id`.** `user<id>@anon.invalid` no revela el mail real, pero permite correlacionar filas entre sí y con cualquier otra copia derivada de `id`.
4. **Equivalencia solo a nivel agregado.** Se demuestra para las agregaciones solicitadas. **No hay equivalencia fila por fila**: los valores son completamente distintos y no se puede reconstruir la fila original.
5. **No es k-anonimidad ni anonimización diferencial.** Es **reemplazo determinista de identificadores con utilidad analítica preservada**. No se aplicaron generalización de `rol`, supresión de celdas pequeñas ni ruido diferencial. Que todos los grupos tengan 2000 o 20000 filas es una propiedad de estos datos, no una garantía del método.
6. **`celular` se descarta por completo** (`NULL`). Se pierde cualquier análisis por zona o por presencia de contacto. Fue una decisión deliberada de privacidad.
7. **`created_at` truncado a mes** impide análisis por día, semana o estacionalidad fina.
8. **La tabla anonimizada sigue siendo un activo sensible.** Aunque no contiene PII directa, conserva `id`, `rol`, `eliminado` y mes; debe mantenerse con los mismos controles de acceso que el resto de la base.

---

## 12. D4 — Respuesta escrita

**¿Qué información concreta de Food Store no debería salir nunca hacia un asistente de IA sin anonimizar antes?**

Nunca deberían salir sin anonimizar los **datos de identidad** (nombre, apellido, documento), los **datos de contacto** (mail, celular, teléfono, dirección), las **credenciales** (contraseñas en claro, hashes, tokens) y cualquier **combinación cuasi-identificadora** —por ejemplo `id` + fecha y hora exacta de alta + rol + zona— que permita reidentificar a una persona cruzando con información externa. Por eso, para análisis asistidos por IA debe usarse una copia como `usuario_anon`, con identificadores sintéticos, contacto suprimido, credenciales reemplazadas por un marcador y granularidad temporal reducida, enviando además solo agregados y no filas individuales.
