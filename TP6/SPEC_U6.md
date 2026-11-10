# SPEC_U6: Plan de Mantenimiento, Respaldo y Recuperación — FoodStore

**Proyecto Integrador:** `foodStore`  
**Materia:** Bases de Datos II — Tecnicatura Universitaria en Programación  
**Entorno Operativo:** PostgreSQL 18 en Windows 11 (PowerShell 5.1/7+)  
**Bases de Datos:** Producción: `foodStore` | Pruebas de Recuperación (descartable): `foodstore_restore_test`  

---

## 1. Propósito y Alcance
Establecer una directiva técnica formal para la administración de la base de datos `foodStore`, garantizando la disponibilidad, integridad lógica y continuidad operativa ante incidentes. Define la automatización modular de respaldos lógicos, auditoría preventiva de salud, mantenimiento estadístico sin bloqueo de tablas y simulacros de recuperación medibles.

---

## 2. Matriz de Frecuencias Mínimas y Criterios de Éxito

| Tarea Mínima | Frecuencia Propuesta | Evidencia Generada | Condición de Éxito / Confirmación |
| :--- | :--- | :--- | :--- |
| **Respaldo Lógico de `foodStore`** | **Diaria** (Ventana nocturna 02:00 hs) | Archivo binario `.dump` en `backups/` con estampa temporal (`foodStore_YYYYMMDD_HHMMSS.dump`) y archivo de traza en `logs/`. | Código de salida (`exit code`) = 0 de `pg_dump`. Archivo generado con tamaño mayor a 0 KB, formato custom (`-Fc`) íntegro verificable con `pg_restore -l`. Log sin advertencias críticas. |
| **Chequeo de Salud (Health Check)** | **Diaria** (07:00 hs, previa apertura operativa) | Salida formateada de `sql/health_check.sql` exportada a log o consola de auditoría. | Conexiones activas dentro del umbral normal (< 80% de `max_connections`); ausencia de bloqueos o estados `idle in transaction` de larga duración; ratio de commits saludable respecto a rollbacks (> 95%). |
| **Revisión de Mantenimiento** | **Semanal** (Domingos 03:00 hs) | Reporte tabular de `sql/maintenance.sql` evaluando bloat, `n_dead_tup`, última ejecución de `autovacuum` y `autoanalyze`. | Porcentaje de tuplas muertas inferior al 15% del total de filas por tabla. Confirmación de actividad del `autovacuum`. Ejecución manual justificada de `ANALYZE` o `VACUUM` estándar (no bloqueante) únicamente ante desfasajes estadísticos observados. |
| **Restauración de Prueba (Disaster Drill)** | **Semanal** (Lunes 08:00 hs en ventana de laboratorio) | Trazas de `restore_test.ps1`, registro de cronómetro (RTO), cálculo de antigüedad (RPO) y validación en `foodstore_restore_test`. | Código de salida 0 en creación (`createdb`) y restauración (`pg_restore --no-owner --no-privileges`). Coincidencia exacta del 100% en conteo de filas en tablas maestras y transaccionales (`categoria`, `usuario` / `usuario_anon`, `producto`, `pedido`, `detalle_pedido`). Cero (0) inconsistencias lógicas detectadas. Eliminación limpia de la base descartable. |

---

## 3. Políticas de Seguridad y Control de Credenciales
1. **No Exposición de Contraseñas:** Queda estrictamente prohibido codificar contraseñas en texto plano dentro de scripts (`.ps1`, `.bat`, `.sql`) o confirmarlas en commits del repositorio Git.
2. **Autenticación Vía `pgpass.conf`:** Se utiliza el mecanismo oficial de PostgreSQL mediante el archivo de contraseñas en Windows ubicado en `%APPDATA%\postgresql\pgpass.conf`, configurado con permisos exclusivos de usuario (`hostname:port:database:username:password`). De manera alternativa temporal, se admiten variables de entorno volátiles en memoria de sesión interactiva (`$env:PGPASSWORD`).
3. **Aislamiento en Git:** El repositorio incluye un archivo `.gitignore` estricto que ignora deliberadamente el contenido de `backups/`, `logs/` y archivos sensibles (`.env`, `pgpass.conf`).
4. **Protección del Entorno Productivo:** Las pruebas de restauración destructivas (`createdb`, `dropdb`, sobreescritura de esquemas) se aplican de forma exclusiva y restringida sobre la base descartable `foodstore_restore_test`. La base de producción `foodStore` nunca se elimina ni se reemplaza durante los simulacros.

---

## 4. Criterio Técnico de Mantenimiento: Política Anti-`VACUUM FULL`
- **Prohibición de `VACUUM FULL` Periódico:** `VACUUM FULL` adquiere un bloqueo exclusivo de tabla (`AccessExclusiveLock`), impidiendo operaciones de lectura (`SELECT`) y de escritura (`INSERT`, `UPDATE`, `DELETE`) de manera concurrente. En un sistema de producción, esto produce una interrupción total del servicio (denegación de servicio no planificada), sumado a un consumo severo de I/O de disco al reescribir físicamente toda la tabla.
- **Estrategia Permitida:** Se prioriza el demonio nativo `autovacuum` de PostgreSQL 18. Cuando se identifique rezago o alta carga transaccional, se autoriza la ejecución manual de `VACUUM` estándar (no bloqueante) y `ANALYZE` sobre tablas específicas, fundamentado en los resultados arrojados previamente por `health_check.sql` y `maintenance.sql`.

---

## 5. Parámetros de Recuperación: RPO y RTO
- **RPO (Recovery Point Objective):** Definido contractualmente en **24 horas** bajo el esquema de respaldo diario programado a las 02:00 hs. Representa la máxima ventana de pérdida de transacciones tolerada ante una catástrofe que requiera restaurar la última copia disponible. En cada simulacro se documenta el RPO observado:  
  $$\text{RPO Observado} = \text{Fecha/Hora de Inicio del Simulacro} - \text{Fecha/Hora del Backup Utilizado}$$
- **RTO (Recovery Time Objective):** Tiempo máximo admisible para reanudar la operación. Para el laboratorio de `foodStore`, se establece una meta de **RTO < 5 minutos**. Se mide de forma automatizada mediante cronómetro en `restore_test.ps1`, computando desde la invocación de `createdb` hasta la finalización exitosa de las consultas de validación lógica de datos.
