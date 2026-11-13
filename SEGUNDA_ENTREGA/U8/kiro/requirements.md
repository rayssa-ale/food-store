# Kiro - Requirements - Unidad 8
## Food Store en la feria: tablet SQLite y sincronizacion simulada

**Contexto.** La tablet vende sin senal. Solo consulta un catalogo cacheado y
arma borradores; PostgreSQL sigue siendo la fuente de verdad de precio, stock y
ventas. Estos requisitos se escribieron antes de generar el esquema y el
semaforo, y cada uno se prueba con un caso C del enunciado.

## REQ-01 - Conflicto de precio

WHEN una solicitud PENDIENTE tiene al menos un item cuyo `precio_centavos_visto`
difiere del `precio_centavos` de `snapshot_servidor`
THE SYSTEM SHALL marcar la solicitud como `CONFLICTO` y registrar en `motivo`
los `producto_id` afectados.

**Se prueba con:** C2 (el servidor sube el precio y luego el cliente acepta).
**Criterio de aceptacion:** la primera solicitud queda `CONFLICTO`; una
solicitud nueva con el precio actualizado queda `SIMULADO_APROBADO`.

## REQ-02 - Rechazo por catalogo o stock

WHEN una solicitud PENDIENTE contiene un producto inexistente en la instantanea,
un producto eliminado o no disponible, o una cantidad mayor que `stock_visto`
THE SYSTEM SHALL marcar la solicitud como `RECHAZADO` y registrar el motivo.

**Se prueba con:** C3 (cantidad 500 sobre stock 106) y C4 (baja logica del
producto).
**Criterio de aceptacion:** ambas solicitudes quedan `RECHAZADO`; en C4 la fila
de `producto_cache` sigue existiendo con `eliminado = 1` y no aparece en el
catalogo disponible.

## REQ-03 - Aprobacion simulada

WHEN una solicitud PENDIENTE tiene todos sus productos disponibles y todos sus
precios y cantidades coinciden con `snapshot_servidor`
THE SYSTEM SHALL marcar la solicitud como `SIMULADO_APROBADO`.

**Se prueba con:** C5 (borrador sin cambios).
**Criterio de aceptacion:** el estado es `SIMULADO_APROBADO` y no se crea ni se
modifica ningun pedido en PostgreSQL.

## REQ-04 - Idempotencia y no reevaluacion

WHEN se reenvia una solicitud con el mismo `solicitud_uuid`
THE SYSTEM SHALL rechazar la insercion por clave primaria y no reevaluar las
solicitudes que ya no estan en estado `PENDIENTE`.

**Se prueba con:** C6 (mismo UUID y segunda corrida del semaforo).
**Criterio de aceptacion:** SQLite devuelve un error de `UNIQUE`; la cantidad de
solicitudes y el `evaluado_en` de la solicitud original no cambian.

## Fuera de alcance

- Interfaz de tablet, aplicacion movil o envio real de red.
- Confirmar ventas o descontar stock en PostgreSQL desde la tablet.
- Resolucion automatica de conflictos: el cliente decide y se crea una nueva
  solicitud.
