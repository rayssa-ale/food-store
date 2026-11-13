# REGISTRO AUDITORÍA CON OPENCODE - PARTE A

## Prompt enviado a OpenCode
`
Actúa como auditor de seguridad PostgreSQL. Audita el archivo roles.sql adjunto 
aplicando principio de mínimo privilegio. Identifica:
1. Permisos excesivos (GRANT ALL, permisos sobre todas las columnas cuando no necesario)
2. Falta de restricciones
3. Problemas con ALTER DEFAULT PRIVILEGES
4. Casos donde se puede aplicar menor privilegio
Propón correcciones concretas con justificación.
`

## Respuesta relevante recibida (resumida)
OpenCode propuso varios ajustes:
- **CASO CRÍTICO - PERMISO EXCESIVO**: Sugirió mantener GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_app_lectura sin restringir la tabla usuario, argumentando "simplicidad". Esto otorgaría SELECT completo incluyendo columnas sensibles (password/hash, datos personales).
- Sugirió agregar GRANT DELETE a rol_app_escritura para "completar operaciones CRUD" sin justificación específica.
- Propuso usar GRANT ALL PRIVILEGES en lugar de privilegios puntuales.
- Recomendó verificar permisos en todas las tablas incluyendo las del sistema.

## Validación o corrección humana aplicada
- **RECHAZADO - Permiso excesivo sobre usuario**: Se mantuvo el enfoque de permiso a nivel de columna. NO se aplicó GRANT SELECT ON ALL TABLES completo. Se otorgaron únicamente las columnas no sensibles: (id_usuario, nombre_usuario, email, fecha_registro). Se justificó que el principio de mínimo privilegio requiere proteger datos sensibles (contraseñas, datos personales) incluso para roles de solo lectura.
- **RECHAZADO - GRANT DELETE general**: No se otorgó DELETE a rol_app_escritura de forma general. Se mantuvo sin DELETE por defecto, requiriendo otorgamiento específico y justificado caso por caso.
- **RECHAZADO - GRANT ALL**: Se rechazaron todas las sugerencias de privilegios amplios. Se mantuvieron solo los privilegios estrictamente necesarios según la especificación de Kiro.
- **ACEPTADO**: Se consideraron las sugerencias sobre ALTER DEFAULT PRIVILEGES y se verificó la cobertura.

**LECCIÓN**: La IA tiende a proponer soluciones más permisivas por simplicidad. Es fundamental validar cada propuesta contra el principio de mínimo privilegio y los requisitos específicos.
