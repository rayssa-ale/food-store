# INFORME POST-INCIDENTE: SIMULACRO DE DESASTRE Y RECUPERACIÓN (UNIDAD 6)

**Materia:** Bases de Datos II — Tecnicatura Universitaria en Programación  
**Proyecto Integrador:** Food Store  
**Entorno Operativo:** PostgreSQL 18 en Windows 11 (PowerShell 5.1)  
**Base de Producción:** `foodStore` | **Base Descartable de Prueba:** `foodstore_restore_test`  
**Fecha del Simulacro:** 2026-10-30 23:28:25  

---

## 1. Resumen Ejecutivo y Metodología
Se ejecutó con éxito el simulacro de recuperación ante desastres sobre una base descartable aislada (`foodstore_restore_test`), protegiendo la base de producción `foodStore` sin interrupciones. 

El proceso automatizó la creación de la base receptora, la restauración del catálogo y datos mediante `pg_restore` (utilizando los parámetros de seguridad `--no-owner --no-privileges`), y la posterior ejecución de consultas de validación de integridad referencial y lógica. Todo el procedimiento se ejecutó bajo estrictas políticas de seguridad: cero contraseñas expuestas en scripts o repositorios, mediante autenticación de sesión en memoria y `%APPDATA%\postgresql\pgpass.conf`.

---

## 2. Cronograma y Métricas de Recuperación (RPO y RTO)

| Parámetro | Definición Conceptual | Valor Previsto / Meta | Valor Real Observado | Evaluación de Cumplimiento |
| :--- | :--- | :--- | :--- | :--- |
| **RPO** *(Recovery Point Objective)* | Máxima antigüedad admisible de los datos ante un siniestro (pérdida potencial de transacciones). | **< 24 horas** (respaldo diario) | **06h 00m 26s** | **CUMPLIDO:** La antigüedad del backup al momento de la catástrofe simulada se ubicó ampliamente dentro de la ventana de 24 hs. |
| **RTO** *(Recovery Time Objective)* | Tiempo total transcurrido desde el inicio de la restauración hasta la puesta en marcha validada. | **< 300 s** *(5 minutos)* | **6.18 segundos** | **CUMPLIDO:** Restauración instantánea y validación lógica completada en un 2.06% del tiempo máximo tolerado. |

- **Respaldo utilizado:** `backups/foodStore_2026-10-30_172759.dump` (Formato Custom `-Fc`, tamaño: 32.62 KB).
- **Inicio del Simulacro:** `2026-10-30 23:28:25` | **Fin con Validación:** `2026-10-30 23:28:31`.

---

## 3. Validación de Integridad de Datos y Restricciones Lógicas

Las validaciones mínimas automatizadas en `foodstore_restore_test` arrojaron consistencia absoluta del 100% respecto a los datos de origen:

| Entidad / Control | Filas Esperadas (Producción) | Filas Restauradas (Prueba) | Inconsistencias Detectadas | Estado |
| :--- | :---: | :---: | :---: | :---: |
| `categoria` | 4 | 4 | 0 | **VÁLIDO** |
| `usuario` *(clientes)* | 5 | 5 | 0 | **VÁLIDO** |
| `producto` | 12 | 12 | 0 | **VÁLIDO** |
| `pedido` | 11 | 11 | 0 | **VÁLIDO** |
| `detalle_pedido` | 20 | 20 | 0 | **VÁLIDO** |
| **Control Lógico 1:** `producto` *(precio < 0 OR stock < 0)* | 0 | 0 | 0 | **VÁLIDO** |
| **Control Lógico 2:** `detalle_pedido` *(cantidad <= 0 OR precio < 0)* | 0 | 0 | 0 | **VÁLIDO** |

---

## 4. Diagnóstico de Monitoreo y Política Técnica de Mantenimiento

1. **Rechazo Técnico a `VACUUM FULL`:**  
   `VACUUM FULL` está **prohibido como mantenimiento periódico** porque adquiere un bloqueo exclusivo total (`AccessExclusiveLock`) que impide consultas de lectura (`SELECT`) y de modificación (`INSERT/UPDATE/DELETE`), provocando la indisponibilidad total del sistema Food Store. Además, duplica el espacio en disco al reescribir físicamente la tabla y satura el subsistema de I/O.
2. **Estrategia Aplicada (`VACUUM ANALYZE`):**  
   Se ejecutó mantenimiento preventivo concurrente mediante `VACUUM (VERBOSE, ANALYZE)` sobre todas las tablas del esquema. Las métricas posteriores en `pg_stat_user_tables` confirmaron la reducción de tuplas muertas a cero (`n_dead_tup = 0`) y la actualización de las estadísticas del optimizador de consultas (`last_analyze`), sin bloquear transacciones concurrentes.

---

## 5. Incidentes Reales Encontrados y Soluciones de Entorno

Durante el desarrollo del laboratorio se detectaron y sortearon tres problemas reales de infraestructura y arquitectura:
1. **Espacios en rutas de Windows:** La presencia de espacios en la ruta del perfil de usuario (`Ivana Gutierrez`) provocaba que `pg_dump` fragmentara el argumento `-f` ("demasiados argumentos en la línea de órdenes"). Se solucionó implementando delimitación y entrecomillado dinámico de argumentos en PowerShell (`backup_foodstore.ps1` y `restore_test.ps1`).
2. **Sensibilidad a Mayúsculas en PostgreSQL (`foodStore`):** El identificador fue creado con mayúscula intermedia. Invocar `pg_dump -d foodstore` provocaba el error `FATAL: no existe la base de datos «foodstore»`. Se unificó el parámetro formal a `foodStore`.
3. **Discrepancia de Catálogo (`cliente` vs. `usuario`):** La plantilla genérica del enunciado referenciaba `cliente`, ausente en el esquema físico (error `SQL 42P01`). Se alinearon los scripts a la entidad real `usuario`.

---

## 6. Mejoras Operativas Propuestas y Verificación del Trabajo Asistido

- **Mejoras para Futuras Ejecuciones:**
  1. *Reducción de RPO:* Configurar archivado continuo de bitácoras WAL (*Write-Ahead Logging*) para habilitar recuperación punto en el tiempo (PITR) y reducir el RPO de 24 horas a menos de 5 minutos.
  2. *Automatización Continua:* Registrar `backup_foodstore.ps1` en el Programador de Tareas de Windows con rotación de copias basada en política abuelo-padre-hijo.
- **Intervención y Verificación del Trabajo Asistido con IA (OpenCode / Antigravity):**  
  Las herramientas de asistencia generativa fueron empleadas para estructurar los borradores de código PowerShell y SQL. Cada bloque de código generado quedó estrictamente subordinado a revisión humana: se corrigieron incompatibilidades del parser de PowerShell 5.1 (remoción del operador `?.` y control de interpolación de variables), se verificó la política de no exposición de claves, y se validó empíricamente cada ejecución contra el motor PostgreSQL 18.
