# Informe de auditoría — Parte B

**Trabajo Práctico Unidad 5 — Administración y seguridad de Food Store: roles, auditoría, incidentes y protección de datos personales**

- **Objeto:** activación, prueba y análisis de la auditoría nativa de PostgreSQL.
- **Motor:** PostgreSQL 17.11 (x86_64-windows, compilado con msvc-19.44.35228, 64 bits).
- **Entorno:** instancia local de desarrollo, servicio `postgresql-x64-17`.
- **Fecha de las pruebas:** 2026-10-24, 15:17:58 a 15:18:20 (UTC-03).
- **Alcance:** únicamente Parte B. No se ejecutaron acciones de las Partes C, D o E.

---

## 1. Objetivo

Activar los parámetros de auditoría nativa de PostgreSQL en la instancia local de Food Store, aplicar los cambios sin reiniciar el cluster, verificar que quedaron efectivos, ejecutar una secuencia controlada de lectura, inserción, actualización e intento de inicio de sesión fallido, y capturar el fragmento crudo del log para analizar su utilidad, sus límites y el carácter sensible del propio archivo de auditoría.

---

## 2. Entorno detectado y trazabilidad

### 2.1. Instancia y rutas

La instancia se detectó con `psql --version`, el servicio de Windows y las vistas del propio motor:

```text
psql (PostgreSQL) 17.11

Servicio: postgresql-x64-17   Estado: Running
Proceso:  postgres (PID 8068 al inicio de la tarea)
```

Las rutas se obtuvieron de `pg_settings` (`config_file`, `data_directory`, `hba_file`, `log_directory`) y de `pg_current_logfile()`:

| Elemento | Valor |
|---|---|
| Versión | PostgreSQL 17.11, 64 bits, Windows |
| `data_directory` | `C:/Users/julic/OneDrive/Desktop/Nueva carpeta/data` |
| `config_file` (`postgresql.conf`) | `C:/Users/julic/OneDrive/Desktop/Nueva carpeta/data/postgresql.conf` |
| `postgresql.auto.conf` | `C:/Users/julic/OneDrive/Desktop/Nueva carpeta/data/postgresql.auto.conf` |
| `hba_file` | `C:/Users/julic/OneDrive/Desktop/Nueva carpeta/data/pg_hba.conf` |
| `log_directory` | `log` (relativo al `data_directory`) |
| Ruta efectiva de logs | `C:/Users/julic/OneDrive/Desktop/Nueva carpeta/data/log/` |
| `log_filename` | `postgresql-%Y-%m-%d_%H%M%S.log` |
| `logging_collector` | `on` (ya venía activo en `postgresql.conf`) |
| Log activo durante las pruebas | `log/postgresql-2026-10-24_000000.log` |
| `log_timezone` | `America/Buenos_Aires` (UTC-03) |

**Trazabilidad de la búsqueda:** no se asumieron rutas. Se consultó `pg_settings` y se confirmó el archivo activo con `pg_current_logfile()`. El `postgresql.conf` real es el de `data/postgresql.conf`; el `ALTER SYSTEM` escribe en `postgresql.auto.conf`, que se lee después y por eso prevalece.

### 2.2. Bases de datos encontradas y decisión

La instancia no tenía una base llamada exactamente `food_store`. Se encontraron estas bases:

| Base | Tamaño | Estado |
|---|---:|---|
| `food_Store` | 8.342 kB | 5 tablas, **0 filas**, sin funciones |
| `foodstore_test` | 168 MB | 5 tablas, **poblada** (10 categorías, 20.000 usuarios, 50.000 productos, 200.000 pedidos, 598.546 detalles) |
| `odontologia_dev` | 8.966 kB | Ajena al proyecto |
| `postgres` | 7.846 kB | Base de mantenimiento |

**Decisión:** la secuencia de prueba se ejecutó contra `foodstore_test`, porque es la única base Food Store poblada con datos compatibles con las unidades 1 a 4. `food_Store` existe pero está vacía (0 filas), por lo que no representa el escenario "base ya poblada" que pide la consigna. La diferencia de nombre y de mayúsculas se documenta explícitamente para que el entorno pueda corregirse si la cátedra exige el nombre exacto `food_store`.

**Función de autenticación:** en `foodstore_test` no existe `fn_autenticar` (sí existen `calcular_total_pedido`, `fn_recalcular_total`, `fn_set_subtotal` y `sp_crear_pedido`). Por eso el intento fallido se realizó con una conexión `psql` y una contraseña incorrecta, que es una de las alternativas admitidas por la consigna.

---

## 3. Configuración aplicada

### 3.1. Método elegido y justificación

Se utilizó **`ALTER SYSTEM`** y luego **`SELECT pg_reload_conf();`**, en lugar de editar `postgresql.conf` a mano.

Justificación:

1. `ALTER SYSTEM` escribe en `postgresql.auto.conf`, un archivo separado y administrado por el motor. Evita errores de sintaxis y no mezcla cambios manuales con la configuración base.
2. Los cambios quedan auditables y reversibles con `ALTER SYSTEM RESET ...` o `ALTER SYSTEM RESET ALL`.
3. Los parámetros elegidos no requieren reinicio: se aplican con recarga (`pg_reload_conf()`), sin reiniciar el cluster ni interrumpir conexiones.
4. No fue necesario editar `postgresql.conf` ni reiniciar el servicio. El archivo se identificó y se verificó, pero la modificación se hizo por la vía administrada del motor.

### 3.2. Parámetros: valores iniciales y finales

| Parámetro | Valor inicial | Valor final | Origen final |
|---|---|---|---|
| `log_connections` | `off` | `on` | `postgresql.auto.conf` |
| `log_disconnections` | `off` | `on` | `postgresql.auto.conf` |
| `log_statement` | `none` | `all` | `postgresql.auto.conf` |
| `log_line_prefix` | `%t` | `%m [%p] %u@%d from %h ` | `postgresql.auto.conf` |
| `logging_collector` | `on` | `on` (sin cambio) | `postgresql.conf` |
| `log_directory` | `log` | `log` (sin cambio) | default |
| `log_filename` | `postgresql-%Y-%m-%d_%H%M%S.log` | igual (sin cambio) | default |

**Por qué `log_statement = 'all'` y no `mod`:**

- `mod` registra DDL y sentencias que modifican datos, pero **no registra un `SELECT` exitoso**. La consigna exige que la lectura deje rastro, por lo que en este laboratorio se eligió `all` para poder evidenciarla.
- En PostgreSQL 17, `log_statement` es un enum con valores `none`, `ddl`, `mod` y `all`. **`ddl,mod` no es un valor válido**: no se acepta una lista separada por comas. `mod` ya incluye las sentencias DDL.
- En un entorno productivo, la recomendación es usar `mod` para reducir volumen y exposición, y complementar la auditoría de lecturas con `pgaudit` (o, para lecturas puntuales, con `log_min_duration_statement`). Se deja `all` porque el objetivo de esta práctica es demostrar la trazabilidad completa de la secuencia.

**Por qué se agregó `log_line_prefix`:**

El valor original `%t` solo aportaba la hora. Se cambió a `%m [%p] %u@%d from %h ` para obtener, en cada línea:

- `%m`: timestamp con milisegundos.
- `%p`: PID del proceso de backend (permite agrupar la sesión).
- `%u`: usuario de la sesión (antes de autenticar aparece como `[desconocido]`).
- `%d`: base de datos.
- `%h`: host cliente.

Sin este prefijo, las sentencias no dirían quién las ejecutó ni desde dónde; solo las líneas de conexión/desconexión lo dirían. Este cambio es clave para responder el Punto 3.

### 3.3. Comandos ejecutados

```sql
ALTER SYSTEM SET log_connections = 'on';
ALTER SYSTEM SET log_disconnections = 'on';
ALTER SYSTEM SET log_statement = 'all';
ALTER SYSTEM SET log_line_prefix = '%m [%p] %u@%d from %h ';
SELECT pg_reload_conf();
```

Resultado de la recarga:

```text
 pg_reload_conf
----------------
 t
(1 row)
```

### 3.4. Verificación con `SHOW` y `pg_settings`

El postmaster conservó el PID 8068 antes y después de la recarga, y el servicio siguió en estado `Running`: no hubo reinicio. La recarga de configuración (`SIGHUP`) fue suficiente porque ninguno de los cuatro parámetros exige reinicio del cluster.

Salida real de la verificación (2026-10-24 15:16:58 -03):

```text
        name        |            setting             |       source       |                               sourcefile
--------------------+--------------------------------+--------------------+-------------------------------------------------------------------------
 log_connections    | on                             | configuration file | C:/Users/julic/OneDrive/Desktop/Nueva carpeta/data/postgresql.auto.conf
 log_directory      | log                            | default            |
 log_disconnections | on                             | configuration file | C:/Users/julic/OneDrive/Desktop/Nueva carpeta/data/postgresql.auto.conf
 log_filename       | postgresql-%Y-%m-%d_%H%M%S.log | default            |
 log_line_prefix    | %m [%p] %u@%d from %h          | configuration file | C:/Users/julic/OneDrive/Desktop/Nueva carpeta/data/postgresql.auto.conf
 log_statement      | all                            | configuration file | C:/Users/julic/OneDrive/Desktop/Nueva carpeta/data/postgresql.auto.conf
 logging_collector  | on                             | configuration file | C:/Users/julic/OneDrive/Desktop/Nueva carpeta/data/postgresql.conf
```

Y las consultas `SHOW` individuales:

```text
 log_connections
-----------------
 on
(1 row)

 log_disconnections
--------------------
 on
(1 row)

 log_statement
---------------
 all
(1 row)

    log_line_prefix
------------------------
 %m [%p] %u@%d from %h
(1 row)
```

El `source = configuration file` y el `sourcefile = ...postgresql.auto.conf` confirman que los valores provienen del `ALTER SYSTEM` y que fueron leídos por el motor. La recarga devolvió `t` y el log posterior demuestra que los parámetros estaban activos.

Contenido resultante de `postgresql.auto.conf`:

```text
# Do not edit this file manually!
# It will be overwritten by the ALTER SYSTEM command.
log_connections = 'on'
log_disconnections = 'on'
log_statement = 'all'
log_line_prefix = '%m [%p] %u@%d from %h '
```

---

## 4. Secuencia de prueba ejecutada

### 4.1. Fecha, base y sentencias

- **Base:** `foodstore_test`.
- **Sesión:** `psql`, usuario `postgres`, host `127.0.0.1`.
- **Inicio:** 2026-10-24 15:17:58.291779 -03.
- **Fin:** 2026-10-24 15:17:58.307935 -03.
- **Duración de la sesión según `log_disconnections`:** 0:00:00.028.

| # | Acción | Sentencia | Resultado |
|---|---|---|---|
| 1 | Lectura de contexto | `SELECT now() AS inicio_prueba;` | `2026-10-24 15:17:58.291779-03` |
| 2 | Lectura | `SELECT count(*) AS total_productos FROM producto;` | `50000` |
| 3 | Inserción | `INSERT INTO categoria (nombre, descripcion) VALUES ('Auditoria TP5 Parte B', 'Registro de prueba para auditoria nativa') RETURNING id, nombre, eliminado;` | `id = 11`, `eliminado = f` |
| 4 | Actualización | `UPDATE categoria SET descripcion = 'Registro actualizado en prueba de auditoria' WHERE nombre = 'Auditoria TP5 Parte B' RETURNING id, descripcion;` | `UPDATE 1`, `id = 11` |
| 5 | Lectura de cierre | `SELECT now() AS fin_prueba;` | `2026-10-24 15:17:58.307935-03` |

**Dato insertado y persistido:** se creó la categoría `id = 11`, `nombre = 'Auditoria TP5 Parte B'` en `foodstore_test.categoria`, y luego se actualizó su descripción. Las operaciones se confirmaron (no se hizo `ROLLBACK`), por lo que el registro queda en la base de prueba. Si se desea limpiar el entorno, la sentencia sería `DELETE FROM categoria WHERE id = 11;` (no se ejecutó para no agregar ruido adicional al log). No se insertaron datos personales ni se modificaron datos de negocio existentes.

### 4.2. Intento de inicio de sesión fallido

```powershell
$env:PGPASSWORD = '<contraseña_incorrecta_de_prueba>'
& 'C:\...\bin\psql.exe' -w -U postgres -h 127.0.0.1 -d foodstore_test -c "SELECT 1;"
```

Resultado en consola:

```text
psql: error: connection to server at "127.0.0.1", port 5432 failed:
FATAL:  la autentificación password falló para el usuario «postgres»
```

La contraseña utilizada fue un valor incorrecto de laboratorio; **no se registra en este informe** y PostgreSQL tampoco la escribe en el log. El intento se hizo después de restaurar `pg_hba.conf` a `scram-sha-256`, para que el fallo fuera real y no un `trust` encubierto.

**Nota de laboratorio:** durante la preparación, la sesión administrativa se habilitó localmente con una regla temporal `trust` solo para `127.0.0.1`, y luego se restauró a `scram-sha-256`. Por eso el fragmento muestra `método=trust` en la sesión de prueba y `scram-sha-256` en el intento fallido. En producción, `trust` sobre TCP no es aceptable; la regla temporal de `127.0.0.1/32` se revirtió a `scram-sha-256` y el archivo final conserva `scram-sha-256` tanto para `127.0.0.1/32` como para `::1/128`.

Verificación final de `pg_hba.conf`:

```text
local   all             all                                     scram-sha-256
host    all             all             127.0.0.1/32            scram-sha-256
host    all             all             ::1/128                 scram-sha-256
local   replication     all                                     scram-sha-256
host    replication     all             127.0.0.1/32            scram-sha-256
host    replication     all             ::1/128                 scram-sha-256
```

---

## 5. Evidencia de log

### 5.1. Archivo y ubicación

| Elemento | Valor |
|---|---|
| Log completo | `C:/Users/julic/OneDrive/Desktop/Nueva carpeta/data/log/postgresql-2026-10-24_000000.log` |
| Fragmento entregado | `docs/log_auditoria_prueba.txt` |
| Tamaño del fragmento | 2.261 bytes, 13 líneas |
| Ventana temporal | 2026-10-24 15:17:58.287 a 15:18:20.888 (UTC-03) |
| SHA-256 del fragmento | `9C2C3C0131782C96A7E026241F2F5B183EBADB1F2ECB634F92C7FBCEA96E6C93` |

El fragmento se copió **byte a byte** desde el log original, desde la primera línea de la conexión de prueba hasta la línea `DETALLE` del fallo de autenticación. No se normalizó ni se reescribió.

**Codificación:** el log de esta instalación mezcla codificación ANSI/Windows-1252 y UTF-8 en los textos localizados. Por ejemplo, en el archivo original `conexión` aparece como `conexi\xf3n` (Windows-1252) y `desconexión` como `desconexi\xc3\xb3n` (UTF-8). Por eso algunos visores pueden mostrar `conexi?n`. Se conservó la codificación original para no alterar la evidencia; en este informe las citas se transcriben con acentos legibles.

**Contenido sensible:** el fragmento incluye la ruta local del laboratorio (`C:/Users/julic/...`) porque PostgreSQL la registra en el `DETALLE` de `pg_hba.conf`; es un dato de trazabilidad del entorno, no un dato de cliente. No contiene contraseñas, tokens ni datos personales de terceros. Aun así, el archivo debe tratarse como evidencia sensible (ver Punto 4).

### 5.2. Fragmento crudo (transcripción legible)

```text
2026-10-24 15:17:58.287 -03 [24792] [desconocido]@[desconocido] from 127.0.0.1 LOG:  conexión recibida: host=127.0.0.1 port=53208
2026-10-24 15:17:58.289 -03 [24792] postgres@foodstore_test from 127.0.0.1 LOG:  conexión autenticada: usuario=«postgres» método=trust (C:/Users/julic/OneDrive/Desktop/Nueva carpeta/data/pg_hba.conf:115)
2026-10-24 15:17:58.289 -03 [24792] postgres@foodstore_test from 127.0.0.1 LOG:  conexión autorizada: usuario=postgres base_de_datos=foodstore_test nombre_de_aplicación=psql
2026-10-24 15:17:58.291 -03 [24792] postgres@foodstore_test from 127.0.0.1 LOG:  sentencia: SELECT now() AS inicio_prueba;
2026-10-24 15:17:58.292 -03 [24792] postgres@foodstore_test from 127.0.0.1 LOG:  sentencia: SELECT count(*) AS total_productos FROM producto;
2026-10-24 15:17:58.297 -03 [24792] postgres@foodstore_test from 127.0.0.1 LOG:  sentencia: INSERT INTO categoria (nombre, descripcion) VALUES ('Auditoria TP5 Parte B', 'Registro de prueba para auditoria nativa') RETURNING id, nombre, eliminado;
2026-10-24 15:17:58.305 -03 [24792] postgres@foodstore_test from 127.0.0.1 LOG:  sentencia: UPDATE categoria SET descripcion = 'Registro actualizado en prueba de auditoria' WHERE nombre = 'Auditoria TP5 Parte B' RETURNING id, descripcion;
2026-10-24 15:17:58.307 -03 [24792] postgres@foodstore_test from 127.0.0.1 LOG:  sentencia: SELECT now() AS fin_prueba;
2026-10-24 15:17:58.308 -03 [24792] postgres@foodstore_test from 127.0.0.1 LOG:  desconexión: duración de sesión: 0:00:00.028 usuario=postgres base=foodstore_test host=127.0.0.1 port=53208
2026-10-24 15:18:10.433 -03 [5360] [desconocido]@[desconocido] from 127.0.0.1 LOG:  conexión recibida: host=127.0.0.1 port=53209
2026-10-24 15:18:20.878 -03 [1180] [desconocido]@[desconocido] from 127.0.0.1 LOG:  conexión recibida: host=127.0.0.1 port=53210
2026-10-24 15:18:20.888 -03 [1180] postgres@foodstore_test from 127.0.0.1 FATAL:  la autentificación password falló para el usuario «postgres»
2026-10-24 15:18:20.888 -03 [1180] postgres@foodstore_test from 127.0.0.1 DETALLE:  La conexión coincidió con el archivo «C:/Users/julic/OneDrive/Desktop/Nueva carpeta/data/pg_hba.conf» línea 115: «host    all             all             127.0.0.1/32            scram-sha-256»
```

### 5.3. Ruido y aclaraciones del fragmento

- **La línea de 15:18:10.433** (`[5360] conexión recibida` sin autenticación ni desconexión) coincide con un intento de conexión abortado durante la preparación (recarga de configuración después de restaurar `pg_hba.conf`). No forma parte de la secuencia funcional de prueba; se conserva porque el fragmento se copió de forma contigua y sin editar. Es el único "ruido" dentro de la ventana.
- **El fallo de autenticación no tiene línea de desconexión** porque no llegó a establecerse una sesión. Solo se registran `conexión recibida` y `FATAL`/`DETALLE`.
- **Las líneas de checkpoint posteriores a las 15:19** (por ejemplo, `empezando checkpoint`, `checkpoint completo`) se excluyeron del fragmento por ser actividad de fondo del motor, no de la secuencia probada.
- **El prefijo `[desconocido]@[desconocido]`** aparece antes de autenticar porque `%u` y `%d` todavía no tienen valor. Una vez autenticado, el mismo PID `24792` pasa a `postgres@foodstore_test`.

---

## 6. Punto 3 — Análisis del fragmento: quién, qué, cuándo, desde dónde y límites

### 6.1. Información útil para auditoría

| Dimensión | Evidencia en el log | Valor aportado |
|---|---|---|
| **Quién** | `postgres` en el prefijo `%u`; `usuario=«postgres»` en la conexión autenticada; `usuario=postgres` en la autorizada | Identifica la cuenta de base de datos que ejecutó las sentencias. En el fallo, identifica la cuenta *intentada* (`postgres`), no una sesión válida. |
| **Qué** | Líneas `sentencia:` con el texto SQL; `INSERT`, `UPDATE`, `SELECT`; `conexión`, `desconexión`, `FATAL` | Permite reconstruir la secuencia exacta de operaciones y distinguir lectura, escritura, conexión y autenticación fallida. |
| **Cuándo** | `%m` = `2026-10-24 15:17:58.287 -03`; duración de sesión `0:00:00.028` | Timestamp con milisegundos y zona horaria, más duración de la sesión. Permite ordenar eventos y medir ventanas. |
| **Desde dónde** | `%h` = `127.0.0.1`; `host=127.0.0.1 port=53208`; `nombre_de_aplicación=psql` | IP y puerto de origen, más el nombre de aplicación declarado por el cliente. |
| **Contexto de sesión** | `%p` = `24792`; `base_de_datos=foodstore_test`; `método=trust` | PID para correlacionar líneas, base objetivo y método de autenticación usado. |
| **Resultado del fallo** | `FATAL: la autentificación password falló`; `DETALLE: ... pg_hba.conf línea 115: ... scram-sha-256` | Confirma el rechazo y la regla exacta de `pg_hba.conf` que lo produjo, lo que ayuda a diagnosticar configuraciones incorrectas. |

**Conclusión del punto 3 (parte útil):** el mecanismo nativo responde razonablemente bien a las cuatro preguntas clásicas de auditoría para eventos de conexión y para el texto de las sentencias. Es suficiente para una primera triage: saber qué cuenta se conectó, desde qué IP, a qué base, cuándo, qué SQL ejecutó y si un intento de autenticación falló.

### 6.2. Qué queda fuera del alcance del mecanismo nativo

1. **No registra resultados ni filas afectadas.** Se ve el `UPDATE`, pero no el valor anterior y posterior de cada fila, ni qué filas coincidieron. Tampoco se ve el conjunto devuelto por un `SELECT`.
2. **No hay auditoría por objeto ni por columna.** El log guarda el texto SQL; para saber que se accedió a `categoria.descripcion` hay que parsear el SQL. No hay una clasificación nativa `READ`/`WRITE`/`DDL` por relación.
3. **No hay contexto de usuario efectivo.** `%u` es el usuario de sesión. En funciones `SECURITY DEFINER`, el usuario efectivo puede ser el dueño de la función; el log nativo no lo distingue con claridad.
4. **Parámetros de consultas preparadas.** Con el protocolo extendido, el texto puede registrarse sin los valores de los parámetros (según `log_parameter_max_length` y el driver). Eso limita la reconstrucción forense.
5. **No es a prueba de manipulación.** Un superusuario de PostgreSQL o un administrador del sistema operativo puede editar o borrar el archivo. No hay encadenamiento de hashes, WORM ni envío obligatorio a un colector externo.
6. **No hay alerta ni correlación.** El log es pasivo: alguien tiene que leerlo o procesarlo. No genera alertas por sí solo.
7. **Costo y exposición.** `log_statement = all` genera volumen y puede capturar datos personales o secretos que aparezcan en el texto SQL. En producción conviene `mod` + `pgaudit` y políticas de retención.
8. **Localización y formato.** El log está localizado en español y en texto libre; parsearlo con herramientas es frágil. Para SIEM conviene `log_destination = 'jsonlog'` (o `csvlog`) y un colector central.
9. **No cubre el nivel de fila.** Para "quién leyó/cambió esta fila" hacen falta triggers de auditoría, CDC (logical decoding) o tablas de historial; el log nativo no lo hace.

### 6.3. `pgaudit` (nocional)

`pgaudit` es una extensión de auditoría de PostgreSQL que se engancha en los hooks del ejecutor y del procesador de utilidades. No se instaló en este trabajo; se describe a nivel conceptual.

Qué aportaría frente al log nativo:

- **Clases de auditoría explícitas:** `READ`, `WRITE`, `DDL`, `ROLE`, `FUNCTION`, `MISC`. Se puede configurar, por ejemplo, `pgaudit.log = 'read, write, ddl, role'` para auditar lecturas y escrituras, no solo modificaciones.
- **Objetos identificados:** con `pgaudit.log_relation = on` registra cada relación involucrada en la sentencia, lo que facilita saber qué tabla se leyó o modificó sin parsear el SQL a mano.
- **Contexto de rol efectivo:** `pgaudit.role` permite auditar las acciones realizadas bajo un rol específico (por ejemplo, un rol de aplicación o un rol de soporte), lo que agrega contexto cuando hay `SECURITY DEFINER` o roles anidados.
- **Parámetros:** `pgaudit.log_parameter = on` puede incluir los valores de los parámetros (con cuidado: puede exponer datos personales; existe `pgaudit.log_parameter_max_size`).
- **Control de volumen:** `pgaudit.log_statement_once` evita repetir la sentencia en cada línea; `pgaudit.log_catalog` permite excluir el catálogo.
- **Formato más estructurado:** sus registros se integran con el logging de PostgreSQL y son más adecuados para un SIEM que el texto libre localizado.

**Precisión importante:** `pgaudit` aporta auditoría **por sentencia y por objeto**, no “fila por fila” con valores antes/después. Para auditoría de fila (quién cambió qué valor) se necesitan triggers de auditoría, tablas de historial, CDC o una solución de base de datos temporal. `pgaudit` tampoco resuelve por sí solo la inmutabilidad: el log sigue siendo un archivo local que hay que centralizar y proteger.

---

## 7. Punto 4 — ¿Es el archivo de log un activo sensible?

**Sí.** El archivo de log es un activo sensible de confidencialidad, integridad y disponibilidad. No es “solo un archivo de texto”: contiene nombres de usuarios y bases, IPs de origen, horarios, texto completo de sentencias SQL, nombres de tablas y columnas, errores de autenticación y, potencialmente, datos personales o secretos que aparezcan en el SQL (por ejemplo, un `CREATE ROLE ... PASSWORD` mal escrito, un `INSERT` con datos de clientes o un `SELECT` con filtros que revelen información). También revela la topología y los hábitos de uso del sistema, lo que es útil para un atacante.

### 7.1. Confidencialidad, integridad y disponibilidad

- **Confidencialidad:** solo deben leerlo las personas con necesidad de conocer: el equipo de auditoría/seguridad, el DBA de guardia y, si corresponde, el responsable de incidentes. No deben leerlo los usuarios de la aplicación, los desarrolladores sin rol de auditoría, ni cuentas genéricas. El acceso a los logs debe quedar registrado y revisarse; la lectura de la auditoría también es un evento auditable.
- **Integridad:** debe ser append-only o, mejor, enviarse a un colector central con almacenamiento WORM. El DBA no debería poder borrar o editar el log que lo audita (separación de funciones). Se recomienda firmar/hashear los segmentos, o al menos usar un servidor de logs remoto con retención y control de acceso independiente.
- **Disponibilidad:** requiere rotación y retención definidas (`log_rotation_age`, `log_rotation_size`, `log_truncate_on_rotation = off`), monitoreo de espacio y respaldo. Un disco lleno por logs puede tumbar el servicio; un log borrado por rotación mal configurada destruye la evidencia.

**Datos personales:** si el texto SQL incluye nombres, documentos, emails, teléfonos o cualquier dato de clientes, el log pasa a ser un registro con datos personales. Se aplican los mismos principios de finalidad, minimización (no registrar más de lo necesario), acceso restringido, retención limitada y borrado seguro. Por eso, en producción no conviene `log_statement = all`: hay que usar `mod` + `pgaudit` con parámetros deshabilitados o acotados, y revisar que el SQL no exponga datos sensibles.

### 7.2. Permisos del sistema operativo y del motor

**Sistema operativo (Windows):**

- El proceso de PostgreSQL (cuenta de servicio `NT AUTHORITY\Servicio de red` / NetworkService) necesita **escritura** sobre el directorio de logs.
- Los administradores del sistema y `SYSTEM` suelen tener control total para operar el servicio; en un esquema de separación de funciones, el DBA de base de datos no debería tener control total sobre el almacenamiento de auditoría.
- El DBA puede tener **lectura** para diagnóstico, pero no borrado ni edición; ese acceso de lectura también debe quedar registrado.
- Debe existir un grupo de **auditoría** con permiso de **solo lectura** sobre el directorio y los archivos.
- Hay que **denegar** la lectura a `BUILTIN\Usuarios`, a cuentas de aplicación y a cualquier usuario interactivo que no sea auditor.
- En Windows no aplica `log_file_mode` (es exclusivo de Unix); se usan ACL de NTFS. Conviene romper la herencia del directorio de logs y definir ACL explícitas.

**Hallazgo real en este equipo:** la ACL del archivo de log y de su directorio otorga:

- `NT AUTHORITY\Servicio de red`: FullControl (necesario para escribir).
- `BUILTIN\Administradores` y `NT AUTHORITY\SYSTEM`: FullControl.
- `Juli\julic`: FullControl (usuario interactivo del laboratorio).
- `BUILTIN\Usuarios`: **ReadAndExecute** (lectura para cualquier usuario local).
- Además, el directorio está bajo `C:\Users\julic\OneDrive\...`, por lo que el contenido puede sincronizarse con OneDrive.

Esto es **demasiado permisivo** para un activo de auditoría: cualquier usuario local puede leer los logs y el archivo puede salir del equipo por la sincronización de OneDrive. En el laboratorio es aceptable como entorno de práctica, pero en un entorno real hay que mover el cluster/logs fuera de una carpeta sincronizada y aplicar una ACL mínima (servicio: escritura; grupo de auditoría: lectura; resto: denegado). Esta es una recomendación de hardening, no un cambio aplicado en esta Parte B.

**Motor PostgreSQL:**

- El archivo de log **no** es accesible por SQL de forma directa para un usuario común. Pueden leerlo cuentas con privilegios de superusuario o roles como `pg_read_server_files` (a través de `pg_read_file`/`pg_read_binary_file`), y `pg_execute_server_program`/`pg_write_server_files` son aún más peligrosos. Estos roles deben estar restringidos al mínimo y nunca otorgarse a roles de aplicación.
- El superusuario `postgres` puede leer y modificar archivos del servidor si tiene acceso al sistema operativo; por eso la separación de funciones y el envío a un colector externo son importantes.
- `pg_monitor`, `pg_read_all_settings` y roles similares permiten ver configuración, pero no leer el archivo de log.
- Se recomienda `log_destination = 'jsonlog'` (o `csvlog`) y un colector central (syslog/rsyslog, SIEM) con control de acceso propio, para que la auditoría no dependa de un archivo local que el propio DBA puede alterar.
- Si se usa `syslog`, debe ir por un canal seguro (TLS) y con un servidor de logs que no esté bajo la misma cuenta administrativa.

### 7.3. Respuesta sintética

El log debe ser tratado como **información clasificada de auditoría**: lectura solo para auditores/seguridad y DBA de guardia, escritura solo para el servicio de PostgreSQL, integridad garantizada por almacenamiento append-only/centralizado, y retención/rotación definidas. En este laboratorio, la ACL de Windows y la ubicación en OneDrive no cumplen ese estándar y quedan documentadas como deuda de hardening.

---

## 8. Conclusión

La auditoría nativa de PostgreSQL, bien configurada, **sí permite detectar** la actividad probada: la conexión y desconexión de una sesión, el usuario, la base, la IP de origen, el texto de las sentencias `SELECT`/`INSERT`/`UPDATE`, y un intento de autenticación fallido con la regla de `pg_hba.conf` que lo rechazó. Para el objetivo de la Parte B, el mecanismo cumplió: los cuatro eventos quedaron en el log y el fragmento es verificable, con timestamps y contexto.

Pero también muestra sus límites: no hay resultados ni valores por fila, no hay auditoría por objeto ni rol efectivo, no es inmutable y no alerta. Para un esquema de auditoría serio hay que sumar `pgaudit` (clases READ/WRITE/DDL, relaciones y rol efectivo), un colector central inmutable, retención/rotación, alertas y una política de mínimo privilegio sobre el propio archivo de log. La configuración `log_statement = all` usada aquí es adecuada para el laboratorio, pero en producción conviene `mod` + `pgaudit` para reducir volumen y exposición.

**Valoración final:** alta utilidad para trazabilidad básica, triage de incidentes y evidencia de laboratorio; insuficiente por sí sola para auditoría forense, cumplimiento estricto o protección de datos personales sin los complementos mencionados.

---

## Anexo A — Comandos clave ejecutados

```sql
-- Rutas y estado inicial
SELECT name, setting, source, sourcefile
FROM pg_settings
WHERE name IN ('data_directory','config_file','hba_file','log_directory',
               'log_filename','logging_collector','log_connections',
               'log_disconnections','log_statement','log_line_prefix',
               'log_min_duration_statement')
ORDER BY name;

SELECT pg_current_logfile();

-- Activación
ALTER SYSTEM SET log_connections = 'on';
ALTER SYSTEM SET log_disconnections = 'on';
ALTER SYSTEM SET log_statement = 'all';
ALTER SYSTEM SET log_line_prefix = '%m [%p] %u@%d from %h ';
SELECT pg_reload_conf();

-- Verificación
SHOW log_connections;
SHOW log_disconnections;
SHOW log_statement;
SHOW log_line_prefix;

-- Secuencia de prueba (foodstore_test)
SELECT now() AS inicio_prueba;
SELECT count(*) AS total_productos FROM producto;
INSERT INTO categoria (nombre, descripcion)
VALUES ('Auditoria TP5 Parte B', 'Registro de prueba para auditoria nativa')
RETURNING id, nombre, eliminado;
UPDATE categoria
SET descripcion = 'Registro actualizado en prueba de auditoria'
WHERE nombre = 'Auditoria TP5 Parte B'
RETURNING id, descripcion;
SELECT now() AS fin_prueba;
```

```powershell
# Intento fallido (contraseña incorrecta de laboratorio; no se documenta el valor)
$env:PGPASSWORD = '<contraseña_incorrecta_de_prueba>'
& 'C:\...\bin\psql.exe' -w -U postgres -h 127.0.0.1 -d foodstore_test -c "SELECT 1;"

# Extracción del fragmento (byte a byte, sin normalizar)
# Se copió desde el log activo a docs/log_auditoria_prueba.txt
```

---

## Anexo B — Estado final del entorno

- `log_connections = on`, `log_disconnections = on`, `log_statement = all`,
  `log_line_prefix = '%m [%p] %u@%d from %h '` en `postgresql.auto.conf`.
- `logging_collector = on`, `log_directory = log`,
  `log_filename = postgresql-%Y-%m-%d_%H%M%S.log`.
- `pg_hba.conf` con `scram-sha-256` en `127.0.0.1/32` y `::1/128` (regla temporal `trust` revertida).
- Registro de prueba `categoria.id = 11` persistido en `foodstore_test`.
- Fragmento de evidencia: `docs/log_auditoria_prueba.txt`
  (2.261 bytes, SHA-256 `9C2C3C0131782C96A7E026241F2F5B183EBADB1F2ECB634F92C7FBCEA96E6C93`).
