# respaldos/

Los respaldos (`*.sql` generados con `pg_dump`) NO se versionan
(ver `.gitignore`). Convención de nombre:

```
food_store_<base>_<AAAAMMDD>.sql
```

Ejemplo: `food_store_dev_20260922.sql`

Antes de cualquier cambio estructural sobre la copia de trabajo se
debe generar uno nuevo (protocolo_seguridad.md, paso 3).