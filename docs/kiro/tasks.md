# Kiro - Tasks - Unidad 8

- [x] T1. Crear `movil/schema_sqlite.sql` con `PRAGMA foreign_keys = ON`, cuatro
  tablas operativas `STRICT` y la tabla de apoyo `snapshot_servidor`.
- [x] T2. Crear `movil/v_snapshot_movil.sql` y exportar
  `movil/servidor_snapshot.csv` desde `foodstore_u8`.
- [x] T3. Importar el CSV en SQLite y cargar `producto_cache` con
  `movil/semaforo.sql`.
- [x] T4. Implementar el semaforo con estados `RECHAZADO`, `CONFLICTO` y
  `SIMULADO_APROBADO`, evaluando solo `PENDIENTE`.
- [x] T5. Ejecutar C2, C3, C4, C5 y C6, guardando evidencia y verificando que
  PostgreSQL no cambio pedidos ni stock.
- [x] T6. Probar C1, borrador con `COMMIT`, operacion con `ROLLBACK` y C7 en
  `movil/pruebas_sqlite.sql`.
- [x] T7. Revisar scripts de la cursada con OpenCode y registrar hallazgos en
  `docs/informe.pdf` y `docs/bitacora_ia.md`.
- [x] T8. Actualizar `README.md` con el orden de creacion desde cero y preparar
  el ensayo de defensa.
