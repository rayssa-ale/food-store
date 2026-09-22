# spec: DESCARTADO indice_pedido_cliente_estado (redundante)

**Propuesta de la IA (probe descartada):**

```sql
CREATE INDEX idx_pedido_cliente_estado ON pedido (cliente_id, estado);
```

**Premisa:** acelerar "historial de un cliente, estado no cancelado"
(query Q2 de la Semana 3).

**Veredicto — DESCARTADO por sobreindexación / redundancia:**

1. `idx_pedido_cliente (cliente_id)` ya reduce los 200 k pedidos a las ~10
   filas del cliente (200 k / 20 k ≈ 10 pedidos por cliente). Leer 10 filas
   con el índice existente y filtrar `estado` en el heap es gratis.
2. `estado` tiene cardinalidad 4 (`ENUM`); agregarlo al compuesto no cambia
   el plan de Q2 (que hoy resuelve en milisegundos con `idx_pedido_cliente`
   + `uq_detalle_pedido_producto`).
3. El costo de escritura sí empeora: cada INSERT/UPDATE en `pedido` debería
   mantener un índice más para un beneficio nulo.

**Decisión:** no se crea. Se documenta aquí y en `informe_mediciones.md` como
ejemplo de "la IA propone, el humano decide con el plan en la mano".

**Contraste con el aceptado:** en el spec `indice_pedido_fecha_estado` la
columna líder (`fecha`) SÍ es selectiva y el índice ataca una consulta que hoy
hace `Seq Scan`; aquí la líder (`cliente_id`) ya está indexada.