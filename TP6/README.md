# TP6 — Unidad 4: FNBC y desnormalización controlada

Entregables del TP6: descomposición FNBC de `control_lote_almacen` y
estructura desnormalizada del top 5 de categorías por día, mantenida con
disparadores.

| Artefacto | Qué demuestra |
|---|---|
| `tp_fnbc_control_lote.sql` | Esquema original, instancia de ejemplo, las 3 anomalías, descomposición FNBC, vista de compatibilidad y migración verificada (`EXCEPT ALL` en ambos sentidos). |
| `tp_desnormalizacion_top_categorias.sql` | Estructura desnormalizada, mecanismo de sincronización, consulta 5.2(d) sobre el cubo y auditoría 5.2(e). |
| `informe_tp6.md` / `TP6_Food_Store.pdf` | DFs y claves candidatas, demostración de violación FNBC, unión sin pérdida, planes EXPLAIN ANALYZE antes/después y justificación del patrón. |
| `planes/` | Salida cruda del motor: planes antes/después y logs de ejecución de ambos scripts. |
| `carga_dia_actual.sql` | Siembra el día corriente (15.000 pedidos / 37.500 líneas) para que el `EXPLAIN ANALYZE` mida un conjunto con datos. |

## Reproducir las mediciones

PostgreSQL 18 local. `psql` no está en el PATH: usar la ruta completa.

```powershell
$env:PGPASSWORD = '<contraseña>'
$psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'

# 1. copia de trabajo desde la base del TP5 (ver ../protocolo_seguridad.md)
#    pg_dump -U postgres food_store_tp5 > respaldos/food_store_tp5_$fecha.sql
#    createdb -U postgres -T food_store_tp5 food_store_tp6

# 2. dia corriente medible
& $psql -U postgres -h localhost -d food_store_tp6 -f TP6/carga_dia_actual.sql

# 3. Parte 1
& $psql -U postgres -h localhost -d food_store_tp6 -v ON_ERROR_STOP=1 -f tp_fnbc_control_lote.sql

# 4. Parte 2
& $psql -U postgres -h localhost -d food_store_tp6 -v ON_ERROR_STOP=1 -f tp_desnormalizacion_top_categorias.sql
```

Los dos scripts son idempotentes (`DROP ... IF EXISTS` + `CREATE`) y todas
sus pruebas se ejecutan dentro de transacciones revertidas: la base queda
con el esquema final y sin datos de prueba.

## Resultado medido

| | Antes (4 tablas) | Después (cubo) |
|---|---|---|
| Nodo dominante | `Parallel Seq Scan` sobre `detalle_pedido` | `Bitmap Index/Heap Scan` sobre `fact_venta_categoria_dia` |
| Filas leídas | ~549.529 para ~31.372 líneas útiles | ~7 (índice) → 3 filas |
| Buffers | hit=1724 read=3280 | hit=6 |
| Tiempo (frío) | 233,234 ms | 0,155 ms |
| Tiempo (caliente, mediana de 5) | 138,0 ms | 0,118 ms |

Ganancia ≈ ×1.170. Detalle y justificación en el informe.

## Regenerar el PDF

```powershell
python TP6\generar_pdf_tp6.py
```

Los bloques de código sin etiqueta en `informe_tp6.md` se renderizan como
salida de plan (envuelve líneas largas); los etiquetados ```` ```sql ````
usan el estilo de código monoespaciado normal.