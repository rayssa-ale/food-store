# Checklist TPI — Food Store · Base de Datos II (UTN)

Verificación de cobertura de los 9 objetivos de la entrega parcial
(Unidades 1-3). Para cada objetivo: **evidencia** (archivo) y **cómo
verificarlo**. Marcar ✔ al presenciar la corrida.

**Motor:** PostgreSQL 18 (≥16 exigido) con PL/pgSQL. Base de verificación:
`food_store_tp5` (creada por copia de `food_store_tp3`).

## 1. Modelo ER (entidades, atributos, claves, cardinalidad, participación)

- **Evidencia:** `TP1/desarrollo_TP1.pdf` (Parte 1) · `TP1/diagrama_ER.png`
  · reglas R1–R7 en `schema.sql`.
- **Verificar:** entidades Cliente/Categoría/Producto/Pedido con atributos y
  claves; cardinalidades 1:N (categoría–producto, cliente–pedido) y N:M
  (pedido–producto); participación total justificada por R1/R2 y parcial por
  R6 (mail único).

## 2. Paso de ER a relacional (1:N y N:M con tabla intermedia)

- **Evidencia:** `TP1/desarrollo_TP1.pdf` (Parte 2) · `schema.sql`.
- **Verificar:** 1:N con FK en el lado N (`producto.categoria_id`,
  `pedido.cliente_id`); N:M resuelta con tabla asociativa `detalle_pedido`
  (FK doble + UNIQUE `(pedido_id, producto_id)`); clave sustituta
  `GENERATED ALWAYS AS IDENTITY` justificada.

## 3. Normalización hasta 3FN/BCNF con justificación de DF

- **Evidencia:** `TP1/desarrollo_TP1.pdf` (Parte 3) · comentarios en
  `schema.sql` (total derivado = DF transitiva evitada; el par
  `(nro_pedido, producto)` define cantidad y `precio_unitario`).
- **Verificar:** una sola tabla plana → 1FN → 2FN → 3FN → BCNF, con la DF
  (`nro_pedido, producto`) → (cantidad, precio_unitario) y la eliminación de
  la dependencia transitiva `nro_pedido` → cliente, forma_pago.

## 4. DDL completo (tipos, PK/FK, restricciones e índices)

- **Evidencia:** `schema.sql`.
- **Verificar:** ENUM (`forma_pago`, `estado_pedido`), `TIMESTAMPTZ`,
  `IDENTITY`, PK, FK con `ON DELETE RESTRICT` (R7), `UNIQUE` (email, nombre
  de categoría, par de detalle), `CHECK` (precios/stock no negativos,
  cantidad positiva), 3 índices justificados (uno parcial: `WHERE activo`).

## 5. DML y consultas (JOIN, agregación, subconsultas, GROUP BY/HAVING, ventana)

- **Evidencia:**
  - JOIN + SUM + GROUP BY: `sql/queries.sql`.
  - Subconsultas + HAVING: `sql/queries_tp4.sql` (T4/T5) y `sql/equivalencias_tp4.sql`.
  - Funciones de ventana: `ROW_NUMBER() OVER` y `SUM(...) OVER (PARTITION BY … ORDER BY …)`
    en `sql/queries_tp4.sql` y `sql/queries_tp4_opt.sql`.
- **Verificar:** ejecutar contra `food_store_tp5`; las equivalencias
  ventana↔subconsulta ya fueron validadas con `EXCEPT` 0 filas
  (`sql/equivalencias_tp4.sql`, sección 3).

## 6. Vistas, funciones y procedimientos almacenados en PL/pgSQL

- **Evidencia:**
  - Vistas: `sql/views.sql` (+ verificación `EXCEPT` 0/0 en `sql/verificacion_views.sql`).
  - Funciones de negocio + procedimiento + JSONB + transición:
    `sql/procedimientos.sql` y `sql/prueba_procedimientos_TPI.sql`.
  - Funciones de trigger R8–R10: `sql/restricciones.sql`.
- **Verificar:** `CALL registrar_reposicion(1, 20)`; `SELECT calcular_total_pedido(212006)`;
  `SELECT resumen_pedido_jsonb(212006)` (devuelve JSONB con líneas y total);
  auditoría 1 fila por sentencia en `auditoria_carga_lineas`.

## 7. Reglas de negocio con CHECK, UNIQUE y triggers

- **Evidencia:** CHECK/UNIQUE en `schema.sql`; triggers R8 (transiciones),
  R9 (stock suficiente), R10 (precio congelado) en `sql/restricciones.sql`;
  casos válidos e inválidos en `sql/` + informe `docs/DUIA_parte1.md`.
- **Verificar:** insertar una línea sin stock → rechazo `R9`; `UPDATE` de
  `estado` fuera de flujo → rechazo `R8`; `UPDATE precio_unitario` →
  rechazo `R10`; mail duplicado → viola `UNIQUE`.

## 8. Transacciones: atomicidad, COMMIT, ROLLBACK, aislamiento y concurrencia

- **Evidencia:**
  - Niveles de aislamiento y anomalías: `docs/informe_concurrencia.md`
    (READ COMMITTED vs REPEATABLE READ; no repetible, fantasma, espera de
    lock 4,51 s, `40P01` y `FOR UPDATE`; 2 sesiones psql).
  - BEGIN/ROLLBACK como protocolo: `docs/ejercicio_lectura_critica.md` y
    `protocolo_seguridad.md`.
  - Atomicidad con auditoría: sección 6 de `sql/prueba_procedimientos_TPI.sql`
    (ROLLBACK revierte la fila de auditoría).
- **Verificar:** correr los 4 escenarios del informe con dos ventanas de
  `psql`; verificar `filas_auditoria_tras_rollback = filas_auditoria_antes`.

## 9. Borrado lógico (soft delete) y su impacto en consultas e índices

- **Evidencia:** columna `activo BOOLEAN` en `categoria` y `producto`
  (`schema.sql`); índice parcial `idx_producto_categoria … WHERE activo = TRUE`;
  vista `v_productos_vigentes` que filtra `activo` (`sql/views.sql`);
  reglas R7 en comentarios del DDL.
- **Verificar:** `UPDATE producto SET activo = FALSE WHERE id = …`; el
  producto desaparece de la carta (`v_productos_vigentes`) y no se puede
  reponer (`CALL registrar_reposicion` lo rechaza), pero el histórico de
  ventas se conserva (no hay DELETE físico; FKs con RESTRICT).

## Nota: elementos específicos de PostgreSQL 16+ exigidos

| Característica | Dónde se demuestra |
|---|---|
| ENUM | `schema.sql` (`forma_pago`, `estado_pedido`) |
| TIMESTAMPTZ | `schema.sql` (`created_at`, `pedido.fecha`) |
| Columnas IDENTITY | `schema.sql` (PK de las 5 tablas) |
| PL/pgSQL | `sql/restricciones.sql`, `sql/procedimientos.sql` |
| PL/pgSQL con JSONB | función `resumen_pedido_jsonb` |
| Procedimiento invocado con CALL | `registrar_reposicion` |
| Tablas de transición en triggers | `trg_detalle_auditoria_carga` (`REFERENCING NEW TABLE`, nivel STATEMENT) |

> Los contadores dependen de la copia de trabajo: los ids de pedido de la
> sección 6 cambian con cada corrida (21xxxx); usar `RETURNING` / `max(id)`.