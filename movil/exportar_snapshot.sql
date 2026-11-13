-- Ejecutar desde la raiz del repo:
-- psql -d foodstore_u8 -f movil/exportar_snapshot.sql
-- psql exporta los booleanos como t/f; el semaforo los normaliza.
\copy (SELECT * FROM v_snapshot_movil ORDER BY producto_id) TO 'movil/servidor_snapshot.csv' CSV HEADER
