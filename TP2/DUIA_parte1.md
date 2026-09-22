# DUIA — Parte 1: Restricciones de integridad (TP2 Food Store)

**Materia:** Base de Datos II — Tecnicatura en Programación (UTN)
**Proyecto:** Food Store — TP2, Parte 1
**Tema:** Garantizar reglas de negocio con el motor (triggers) usando
OpenCode en modo Plan y revisión humana del diff.

## Herramientas usadas

| Herramienta | Uso |
|---|---|
| **OpenCode** (CLI, modelo *big-pickle) | Motor primario: especificación, diseño de triggers, ejecución controlada y verificación en el motor. |
| **PostgreSQL 18** (local) | Motor donde se aplicaron y verificaron las restricciones sobre la copia `food_store_dev`. |
| **Git** | Versionado por parte; revisión del `git diff` antes del commit. |

## Modo de trabajo IA (requisito del TP)

1. **Modo Plan**: se describió en chat el conjunto de reglas de negocio
   candidatas y cómo se garantizaría cada una (tabla → trigger).
2. **Generación**: OpenCode produjo `sql/restricciones.sql` a partir de la
   especificación aprobada.
3. **Revisión humana del diff**: se ejecutó `git diff --cached` y se
   revisó el archivo completo antes de commitear (prueba: `git diff --
   cached --stat` más lectura línea por línea).
4. **Verificación en el motor**: aplicación en transacción + casos
   válidos e inválidos con salida real de PostgreSQL.

## Especificación (prompt / spec aplicados)

| # Regla | Regla de negocio | Garantía implementada | Ejemplo de violación que hoy pasaba |
|---|---|---|---|
| R8 | El estado del pedido no puede retroceder ni cambiar desde un estado terminal | Trigger `trg_pedido_estado_transicion` (`BEFORE UPDATE OF estado`) | `UPDATE pedido SET estado='PENDIENTE' WHERE id=2` (EN_PREPARACION) |
| R9 | No se venden más unidades de las disponibles; el stock se descuenta al vender | Trigger `trg_detalle_stock` (`BEFORE INSERT`) con `UPDATE producto ... WHERE stock >= cantidad` | `INSERT detalle (producto 6, cantidad 9999)` con stock 12 |
| R10 | El precio unitario de la línea ya creada es inmodificable (refuerza R4) | Trigger `trg_detalle_precio_congelado` (`BEFORE UPDATE OF precio_unitario`) | `UPDATE detalle_pedido SET precio_unitario=500 WHERE id=1` |

Prompt usado (resumen): *«Garantizá en el motor las reglas R8 (estados
de pedido sin retroceso ni modificación de terminales), R9 (stock
suficiente y descuento atómico) y R10 (precio de línea congelado,
refuerzo de R4) mediante triggers plpgsql sobre el esquema Food
Store. Aplicá dentro de una transacción sobre la copia y probá casos
válidos e inválidos.»*

## Pruebas ejecutadas (salidas reales de PostgreSQL)

**Válidas** (dentro de la transacción de aplicación, COMMIT final):
- `V1` PENDIENTE→EN_PREPARACION: `UPDATE 1`.
- `V2` línea con stock suficiente: `INSERT 0 1`; stock del producto 5
  descontado (30 → **29**).
- `V3` pedido PENDIENTE→CANCELADO (no terminal): `INSERT 0 1 ` + `UPDATE 1`.

**Inválidas** (cada una en su transacción, ROLLBACK de la tx abortada):
- `I1` EN_PREPARACION→PENDIENTE → `ERROR R8: transición de estado inválida`.
- `I2` ENTREGADO→CANCELADO → `ERROR R8: pedido 1 en estado terminal (ENTREGADO)`.
- `I3` cantidad 9999 con stock 12 → `ERROR R9: stock insuficiente`.
- `I4` modificar precio_unitario → `ERROR R10: ... congelado (R4)`.
- Control final: pedidos `4`, detalle total `6`, líneas del pedido 2
  intactas (`2`) — no quedaron huellas de los casos rechazados.

## Revisión humana aplicada

- Cada trigger se leyó y se justificó contra la regla de negocio antes
  de ejecutarse (protocolo_seguridad.md).
- El diff del commit (197 líneas sumadas) se revisó antes de versionar.
- Los errores de cada caso inválido fueron **verificados en el motor**,
  no solo predichos por la IA.