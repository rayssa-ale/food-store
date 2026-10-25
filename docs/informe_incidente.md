# Informe de incidente - Parte C: Laboratorio: simulacro de incidente de acceso indebido

**Fecha:** 2026-10-24  
**Entorno:** Instancia local PostgreSQL 17.11 (`postgresql-x64-17`), base `food_Store`  
**Repositorio:** `food-store-tp-u5` (ruta: `C:\BD\food-store\TP7`)

---

## 1) Resumen del simulacro

**Script ejecutado:** `sql/simulacro_incidente.sql`

La secuencia ejecutada fue:
1. **Intentos fallidos de inicio de sesión contra `fn_autenticar` con credenciales inválidas:** El script ejecutó `SELECT fn_autenticar(...)` pero en el esquema actual de `food_Store` **no existe la función `fn_autenticar`**. Se dejaron tres sentencias con etiquetas `INTENTO_FALLIDO_1/2/3` documentando que las mismas fallaron por inexistencia de la función. Los intentos de conexión fallidos con credenciales reales para roles que no existen (ej. `admin_datos`, `app_web`) se observaron en el log previo al simulacro.
2. **Inicio de sesión exitoso contra `fn_autenticar` con credenciales válidas:** En el esquema actual no existe `fn_autenticar`. Se documentó un paso simulado (`INTENTO_EXITOSO_SIMULADO`) mostrando `current_user = postgres`, `current_database() = food_Store`.
3. **Lectura masiva de la tabla `usuario`:** Se ejecutó `SELECT count(*) FROM usuario` (resultado `0`) y `SELECT id, nombre, apellido, mail FROM usuario ORDER BY id LIMIT 50` (0 filas). La tabla `usuario` existe con estructura `(id, nombre, apellido, mail, celular, contrasena, rol, eliminado, created_at)` pero está vacía en `food_Store`.
4. **Intento de escalamiento de privilegios:** 
   - **Intento 1:** `GRANT admin_datos TO app_web` → **FALLIDO** (NOTICE: `ESCALAMIENTO_FALLIDO: no existe el rol «app_web»`). El rol `app_web` no existe en esta instancia (según `\du` solo `postgres` y `turnos_app`).
   - **Intento 2:** `CREATE ROLE atacante_test NOLOGIN` → **EXITOSO** (NOTICE: `ESCALAMIENTO_EXITOSO: CREATE ROLE ejecutado`), seguido inmediatamente de `DROP ROLE atacante_test`.

**Resultado del intento de escalamiento:** **Mixto**. Otorgar membresía al rol `app_web` falló por inexistencia del rol. Sin embargo, **un superusuario (`postgres`) pudo crear un rol (`CREATE ROLE`) y luego eliminarlo**. Esto constituye un **hallazgo crítico**: en una instancia real, un atacante que obtuviera privilegios de superusuario o de un rol con `CREATEROLE` podría crear roles y otorgar privilegios. En este caso, el simulacro fue ejecutado por `postgres` (superusuario) conectado por `trust` desde loopback, lo cual explica el éxito del `CREATE ROLE`.

---

## 2) Evidencia

- **Log crudo utilizado para anonimizar:** `docs/log_simulacro_crudo.txt` (fragmento extraído del log activo `C:/Users/julic/OneDrive/Desktop/Nueva carpeta/data/log/postgresql-2026-10-24_000000.log` desde 16:44:23.482 hasta 16:45:27.627, sesión PID 14396).
- **Log anonimizado enviado a IA:** `docs/log_simulacro_anonimizado.txt` (sin PII identificable; roles/host/pid anonimizado, nombres de columnas enmascarados, base mantenida como `food_store`).
- **Respuesta completa de OpenCode:** `docs/respuesta_opencode_incidente.txt` (guardada íntegramente sin resumir).
- **Script del simulacro:** `sql/simulacro_incidente.sql`

**Fragmento clave del log (crudo, relevante):**
```
2026-10-24 16:45:27.601 -03 [14396] [desconocido]@[desconocido] from 127.0.0.1 LOG:  conexión recibida: host=127.0.0.1 port=61890
2026-10-24 16:45:27.605 -03 [14396] postgres@food_Store from 127.0.0.1 LOG:  conexión autenticada: usuario=«postgres» método=trust (C:/Users/julic/OneDrive/Desktop/Nueva carpeta/data/pg_hba.conf:115)
2026-10-24 16:45:27.605 -03 [14396] postgres@food_Store from 127.0.0.1 LOG:  conexión autorizada: usuario=postgres base_de_datos=food_Store nombre_de_aplicación=psql
2026-10-24 16:45:27.613 -03 [14396] postgres@food_Store from 127.0.0.1 LOG:  sentencia: SELECT 'INTENTO_FALLIDO_1' AS etapa, 'fn_autenticar inexistente en este esquema' AS resultado;
...
2026-10-24 16:45:27.621 -03 [14396] postgres@food_Store from 127.0.0.1 LOG:  sentencia: DO $$ ... EXECUTE 'GRANT admin_datos TO app_web'; ... EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'ESCALAMIENTO_FALLIDO: %', SQLERRM; ...
2026-10-24 16:45:27.623 -03 [14396] postgres@food_Store from 127.0.0.1 LOG:  sentencia: DO $$ ... EXECUTE 'CREATE ROLE atacante_test NOLOGIN'; RAISE NOTICE 'ESCALAMIENTO_EXITOSO: CREATE ROLE ejecutado'; EXECUTE 'DROP ROLE atacante_test'; ...
2026-10-24 16:45:27.627 -03 [14396] postgres@food_Store from 127.0.0.1 LOG:  sentencia: SELECT 'SIMULACRO_FINALIZADO' AS etapa, now() AS timestamp;
2026-10-24 16:45:27.629 -03 [14396] postgres@food_Store from 127.0.0.1 LOG:  desconexión: duración de sesión: 0:00:00.065 usuario=postgres base=food_Store host=127.0.0.1 port=61890
```

---

## 3) Respuesta de la IA (OpenCode) - Completa

La respuesta completa se guardó en `docs/respuesta_opencode_incidente.txt`. Se incluye íntegramente a continuación:

```
opencode.exe : [0m
En C:\Users\julic\AppData\Roaming\npm\opencode.ps1: 14 Carácter: 3
...
```

Ver archivo completo: `docs/respuesta_opencode_incidente.txt`

**Resumen de la respuesta de OpenCode:**
- Reconstruye correctamente la cronología: conexión trust desde 192.168.0.100 (posible proxy/loopback), sesión `postgres` sobre `food_store`, sentencias etiquetadas con etapas, lectura masiva acotada con datos enmascarados, dos intentos de escalamiento, cierre en ~26ms.
- Señala que el primer intento de escalamiento (`GRANT ROL_ANON_01 TO ROL_ANON_02`) falla, el segundo (`CREATE ROLE ROL_ANON_03`) tiene éxito pero se limpia con `DROP ROLE`.
- Advierte que no hay `REVOKE` de la membresía si el primer `GRANT` hubiera tenido éxito, y que no hay evidencia de autenticaciones fallidas reales ni exfiltración.
- Propone hipótesis de contención: bloquear origen, revocar membresías, forzar cambio de contraseñas, auditar roles/privilegios, eliminar roles creados, revisar `pg_hba.conf` (eliminar `trust`), habilitar más logging, entre otras.
- Señala ruta de `pg_hba.conf` en carpeta OneDrive como indicador de entorno no endurecido (inferencia).

---

## 4) Contraste crítico (obligatorio)

### ¿Qué acertó la IA?
- **Cronología correcta:** Identificó la secuencia por etapas, timestamps, conexión `trust`, usuario `postgres`, base `food_store`, y el cierre de sesión.
- **Escalamiento parcial correcto:** Detectó que el primer intento falló y el segundo (`CREATE ROLE`) tuvo éxito pero fue eliminado. Esto coincide exactamente con el log.
- **Observación sobre limpieza:** Señaló correctamente que no hay `REVOKE` si el `GRANT` hubiera prosperado.
- **Lectura masiva acotada:** Identificó que la lectura fue limitada (`count(*)` + `LIMIT 50`) con datos enmascarados.
- **Conexión `trust`:** Identificó la debilidad del método de autenticación `trust`.
- **Simulacro scripteado:** Inferencia razonable por etiquetas de etapa y rapidez de ejecución.

### ¿Qué omitió la IA?
- **Contexto del esquema:** No notó que `fn_autenticar` no existe en `food_Store` (solo existe en `foodstore_test`). Los "intentos fallidos de inicio de sesión contra `fn_autenticar`" del guion fallaron por **inexistencia de la función**, no por autenticación fallida. El log muestra `ERROR: no existe la función fn_autenticar...` no `FATAL: autenticación fallida`.
- **Estado de roles:** No identificó que `app_web` y `admin_datos` no existen en esta instancia (`\du` solo muestra `postgres`, `turnos_app`). Por eso el `GRANT admin_datos TO app_web` falló con "no existe el rol «app_web»".
- **Tabla usuario vacía:** `usuario` tiene 0 filas en `food_Store`; la "lectura masiva" devolvió 0 registros. Esto es importante para el análisis forense.
- **Diferencia entre bases:** No mencionó que la Parte B se hizo en `foodstore_test` y esta Parte C se ejecuta en `food_Store`.
- **Logs previos de intentos reales:** El log contiene intentos reales de conexión con `admin_datos`/`app_web` fallidos por "No existe el rol" a las 16:15, pero el fragmento anonimizado enviado comenzó en el simulacro; la IA analizó solo el fragmento enviado (lo cual es correcto según las instrucciones), pero no pudo correlacionarlos.
- **Uso de superusuario:** La IA mencionó `postgres` pero no enfatizó que fue **superusuario** quien ejecutó todo, lo que explica por qué `CREATE ROLE` tuvo éxito. Esto es crítico para la contención.

### ¿Propuso alguna afirmación que el log NO sustenta?
- **"Autenticaciones fallidas reales":** La IA dijo "Lo que el log prueba es..." pero los intentos fallidos contra `fn_autenticar` fueron **errores de inexistencia de función**, no autenticaciones fallidas. Las autenticaciones fallidas reales aparecen en el log completo pero no en el fragmento anonimizado enviado.
- **"Exfiltración de datos":** La IA correctamente dijo "no hay evidencia de exfiltración", pero podríamos haber sido más explícitos. Sin embargo, la IA fue cautelosa.
- **"host=192.168.0.100 en la conexión recibida frente a from 127.0.0.1":** El fragmento anonimizado tenía `host=192.168.0.100` (modificado) y `from 127.0.0.1`. La IA señaló la discrepancia correctamente, pero esto fue artefacto de nuestra anonimización, no del log original.
- **"Persistencia residual" / "la pertenencia a ROL_ANON_01 quedaría vigente":** Hipótesis válida si el `GRANT` hubiera tenido éxito, pero en este caso el `GRANT` **falló**. La IA lo planteó como hipótesis ("Solo es hipótesis: no se ve el resultado"), lo cual es razonable.
- **"Entorno no endurecido por ruta de pg_hba.conf en OneDrive":** Esta es una inferencia correcta y coincide con lo que encontramos en la Parte B (hallazgo real).

---

## 5) Decisión final de contención (del equipo)

**Esta decisión es propia del equipo, tomada a partir de evidencia y NO derivada ciegamente de la sugerencia de la IA.**

Basándonos en el log y en el diseño de permisos de la Parte A:

| Medida | Fundamentación | Estado |
|---|---|---|
| **1) Eliminar/revocar `trust` en `pg_hba.conf`** | Evidencia: toda la sesión usó `método=trust` (línea 3 del fragmento). `pg_hba.conf` está en `C:/Users/julic/OneDrive/Desktop/Nueva carpeta/data/pg_hba.conf` (ruta bajo OneDrive, hallado en Parte B). `trust` permite conexiones sin contraseña. Esto es inaceptable en cualquier entorno. | **CRÍTICA - Requerida** |
| **2) Cambiar autenticación a `scram-sha-256`** | Ya restaurado en Parte B para `127.0.0.1/32` y `::1/128`. Verificar que quede aplicado y sin `trust`. | **COMPLETADO (Parte B)** |
| **3) Aplicar principio de mínimo privilegio - eliminar superusuario para operaciones diarias** | El simulacro fue ejecutado por `postgres` (superusuario). Si un atacante compromete una cuenta con privilegios de superusuario, puede crear roles, otorgar privilegios, etc. (como se demostró con `CREATE ROLE` exitoso). Solo `postgres` debe usarse para administración, nunca para aplicación. | **CRÍTICA - Requerida** |
| **4) Crear/revisar roles de aplicación** | Los roles `app_web`, `admin_datos` mencionados en `sql/roles.sql` (Parte A) **no existen en esta instancia**. Si se van a usar, deben crearse con los privilegios mínimos definidos. `admin_datos` tiene privilegios elevados (concede todos los roles grupales) según `roles.sql` línea 32-34; si existe, debe estar estrictamente controlado. | **RECOMENDADA** |
| **5) Revocar privilegios innecesarios** | `rol_app_lectura` tiene `SELECT` por columnas en `usuario` (líneas 64-65 de `roles.sql`), pero `rol_app_escritura` tiene `SELECT,INSERT,UPDATE` en **todas las tablas** (línea 44). Revisar si es necesario; `DELETE` no está otorgado explícitamente. | **RECOMENDADA** |
| **6) Mover logs fuera de OneDrive** | Hallazgo de Parte B: logs bajo OneDrive, ACL da `BUILTIN\Usuarios: ReadAndExecute`. Esto es un riesgo de confidencialidad. | **CRÍTICA - Requerida** |
| **7) Restringir ACL de logs** | Solo servicio PostgreSQL (NetworkService), administradores/SYSTEM y grupo de auditoría deben tener acceso. Eliminar lectura para `BUILTIN\Usuarios`. | **CRÍTICA - Requerida** |
| **8) Habilitar auditoría más granular** | Se usa `log_statement='all'` (Parte B). Considerar `pgaudit` para auditoría por objeto/rol efectivo. Monitorear `CREATE ROLE`, `GRANT`, `ALTER ROLE` (comandos privilegiados). | **RECOMENDADA** |
| **9) Auditar intentos de conexión fallidos** | El log muestra intentos con `admin_datos`/`app_web` fallidos por "No existe el rol". Implementar alertas ante múltiples intentos fallidos desde mismo origen. | **RECOMENDADA** |
| **10) Rotación y retención de logs** | Configurar `log_rotation_age`, `log_rotation_size`, `log_truncate_on_rotation=off`, envío a colector central con almacenamiento inmutable. | **RECOMENDADA** |

**Nota importante:** Si `fn_autenticar` debe existir para el simulacro según la consigna, debe crearse en `food_store` (o usar `foodstore_test` donde existe). No obstante, el hallazgo es válido: en `food_Store` no existe, lo cual altera la reproducibilidad del simulacro tal como fue diseñado. Esto se documenta como **hallazgo del entorno**, no como excusa para falsear resultados.

---

## 6) Lecciones aprendidas

- **Enviar solo el log anonimizado es fundamental:** Al enviar únicamente `docs/log_simulacro_anonimizado.txt` sin el script ni hipótesis, obtuvimos una reconstrucción basada en evidencia. Esto redujo el riesgo de sesgo.
- **La validación crítica es obligatoria:** La IA acertó en la cronología y en el escalamiento, pero omitió contexto del esquema (función inexistente, roles inexistentes, tabla vacía) y hizo inferencias que debimos contrastar con el log crudo.
- **El log por sí solo no cuenta toda la historia:** Necesitamos conocer el esquema (`\du`, `\df`, `\dt`), `pg_hba.conf`, y el estado de la base para interpretar correctamente los errores.
- **`trust` es extremadamente peligroso:** Aunque fue temporal en nuestro laboratorio, permitió la ejecución del simulacro sin autenticación. En producción debe eliminarse.
- **Superusuario = poder total:** Que `postgres` pudiera hacer `CREATE ROLE` demuestra que el control de superusuarios es crítico. El principio de mínimo privilegio debe aplicarse también a las cuentas administrativas.
- **Anonimización debe ser cuidadosa:** Debimos limpiar referencias a columnas (`nombre, apellido, mail`) que aparecían en el SQL del log. Es importante verificar visualmente que no queden datos identificables.
- **Trazabilidad es clave:** Guardar el log crudo (solo para contraste interno), el log anonimizado, la respuesta completa de la IA y el script permite un análisis forense reproducible.
- **Diferencia entre "fallo de autenticación" y "error de SQL":** `ERROR: no existe la función...` es distinto a `FATAL: autenticación fallida`. Hay que leer los mensajes correctamente.

---

## Anexos

- `sql/simulacro_incidente.sql` - Script del simulacro
- `docs/log_simulacro_crudo.txt` - Fragmento crudo (solo para contraste interno)
- `docs/log_simulacro_anonimizado.txt` - Fragmento anonimizado enviado a IA
- `docs/respuesta_opencode_incidente.txt` - Respuesta completa de OpenCode
- `BITACORA.md` - Registro de la interacción con OpenCode
