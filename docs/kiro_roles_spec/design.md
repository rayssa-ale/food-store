# design.md

## Principios
- Principio de mínimo privilegio
- Separación de responsabilidades
- Trazabilidad
- Deny by default

## Mapeo de privilegios

### rol_app_lectura
- Operación habilitada: SELECT en tablas necesarias para lectura
- Justificación: Solo lectura, sin modificación
- Tablas: producto, categoria, cliente (según necesidad)
- Sin acceso a: usuario (datos sensibles), logs, configuraciones

### rol_app_escritura
- Operación habilitada: SELECT, INSERT, UPDATE en tablas operativas
- Justificación: Operaciones CRUD necesarias para la app
- Restricciones: NO DELETE masivo, acceso limitado

### rol_soporte
- Operación habilitada: Operaciones de soporte limitadas
- Justificación: Soporte técnico con restricciones
- Acceso controlado

### rol_reportes
- Operación habilitada: SELECT solo lectura para reportes
- Justificación: Generación de informes sin modificar datos

### app_web
- Hereda de: rol_app_lectura, rol_app_escritura (según necesidad)
- Uso: Conexión desde aplicación web
- LOGIN habilitado

### admin_datos
- Privilegios elevados pero controlados
- Justificación: Administración de datos con supervisión

## Permisos a nivel de columna
Se aplicará GRANT SELECT/UPDATE sobre columnas específicas de la tabla usuario cuando sea necesario,
en lugar de otorgar permisos sobre toda la tabla.

## ALTER DEFAULT PRIVILEGES
Se configurará para que las tablas futuras en el schema public hereden los privilegios
correctos para los roles de aplicación.
