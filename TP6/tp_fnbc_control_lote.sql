-- ============================================================
-- FOOD STORE — Unidad 4 · TP6 · Parte 1
-- Forma Normal de Boyce-Codd sobre ControlLoteAlmacen
--
-- Entregable: tp_fnbc_control_lote.sql
-- Base de trabajo: food_store_tp6
--
--   & $psql -U postgres -h localhost -d food_store_tp6 \
--       -v ON_ERROR_STOP=1 -f TP6/tp_fnbc_control_lote.sql
--
-- ------------------------------------------------------------
-- (a) DEPENDENCIAS FUNCIONALES
--
-- La regla de negocio relevada con el área de logística tiene dos
-- cláusulas, y cada una es una DF:
--
--   1) "Para un lote y un depósito interviniente dados, el
--       responsable de control queda unívocamente determinado."
--        ->  {LoteID, DepositoID} -> {ResponsableControlID}
--           (FD1)
--
--   2) "Cada responsable de control pertenece, como dato maestro
--       de la dotación de personal, a un único depósito: no
--       controla lotes coordinados desde depósitos distintos."
--        ->  {ResponsableControlID} -> {DepositoID}
--           (FD2)
--
-- F+ mínima sobre R = {LoteID, DepositoID, ResponsableControlID}:
--   F+ = { {LoteID, DepositoID} -> ResponsableControlID,
--           {ResponsableControlID} -> DepositoID }
--
-- FD1 tiene por determinante la clave primaria declarada, así que
-- no puede violar nada: el esquema la garantiza por construcción.
-- La FD2 es la que hay que examinar.
--
-- ------------------------------------------------------------
-- (b) CLAUSURAS Y CLAVES CANDIDATAS
--
-- Notación X+ = clausura del conjunto X bajo F+.
--
--   {LoteID}+                 = {LoteID}
--   {DepositoID}+             = {DepositoID}
--   {ResponsableControlID}+   = {ResponsableControlID, DepositoID}   (por FD2)
--
--   {LoteID, DepositoID}+     = {LoteID, DepositoID, ResponsableControlID}
--   {LoteID, ResponsableControlID}+ = {LoteID, ResponsableControlID, DepositoID}
--                                    (por FD2 se consigue DepositoID,
--                                     y con el par de FD1 ya no queda
--                                     nada que agregar)
--   {DepositoID, ResponsableControlID}+ = {DepositoID, ResponsableControlID}
--                                    (FD2 no aporta nada nuevo)
--
-- Superclaves = todo conjunto cuya clausura es R. De la lista:
--   {LoteID, DepositoID}       superclave, y MINIMAL (ninguno de sus
--                              subconjuntos {LoteID} ni {DepositoID}
--                              la es) -> clave candidata
--   {LoteID, ResponsableControlID}  superclave, y MINIMAL ({LoteID}
--                              ni {ResponsableControlID} la son)
--                              -> clave candidata
--
-- CONJUNTO COMPLETO DE CLAVES CANDIDATAS:
--   K1 = {LoteID, DepositoID}                    (la elegida como PK)
--   K2 = {LoteID, ResponsableControlID}
--
-- Atributos PRIMOS (pertenecen a alguna clave candidata):
--   LoteID             primo (está en K1 y en K2)
--   DepositoID         primo (está en K1)
--   ResponsableControlID  primo (está en K2)
--
-- Atributos NO primos: NINGUNO. Los tres son primos.
--
-- Observación decisiva para el punto (c): que no haya atributos no
-- primos es exactamente lo que hace que 3FN no detecte nada acá.
--
-- ------------------------------------------------------------
-- (c) ¿CUMPLE FNBC?
--
-- Definición formal de FNBC (no la de 3FN): una relación r está en
-- FNBC si y sólo si para TODA dependencia funcional X -> Y que se
-- cumple en r, X es una superclave de r.
--
-- Se examinan las dos DF de F+:
--
--   FD1: determinante {LoteID, DepositoID} = K1 = superclave  -> no viola
--
--   FD2: determinante {ResponsableControlID}. ¿Es superclave?
--        {ResponsableControlID}+ = {ResponsableControlID, DepositoID}
--        y R = {LoteID, DepositoID, ResponsableControlID}.
--        La clausura NO contiene LoteID, así que NO es superclave.
--        -> VIOLA LA FNBC.
--
-- CONCLUSIÓN: control_lote_almacen NO cumple la FNBC.
--
-- Y cumple 3FN: como no existe ningún atributo no primo, la
-- definición de 3FN (todo determinante no trivial es superclave o
-- es atributo primo) se satisface sin que ninguna DF sea superclave.
-- Éste es el caso canónico donde 3FN y FNBC se separan.
--
-- ------------------------------------------------------------
-- (d) LAS TRES ANOMALÍAS (demostradas con SQL al final del script)
--
-- Las tres habilita la misma DF2: como el depósito es un dato que
-- se deduce del responsable y no del par (lote, depósito), el
-- depósito no tiene vida propia en la relación y su valor real
-- queda escondido dentro de las filas de asignación.
-- ============================================================

BEGIN;

-- ============================================================
-- MAESTRAS ASUMIDAS EXISTENTES
--
-- El enunciado declara que lote, deposito y usuario ya existen, de
-- manera análoga a como se asumió existente `sucursal` en el caso
-- AsignacionEntrega. No existen en Food Store, así que se crean
-- mínimas y sólo con lo que el caso necesita.
--
-- NOTA DE DISEÑO IMPORTANTE sobre `usuario`: deliberadamente NO
-- lleva columna deposito_id. Si el maestro de personal ya guardara
-- el depósito del responsable, la DF2 quedaría resuelta en el
-- maestro, control_lote_almacen no la contendría, y este trabajo
-- no tendría nada que descomponer. Poner el dato ahí sería
-- exactamente la premisa que el enunciado pide corregir.
-- ============================================================
DROP TABLE IF EXISTS control_lote_almacen;
DROP TABLE IF EXISTS control_lote;
DROP TABLE IF EXISTS responsable_deposito;
DROP TABLE IF EXISTS usuario;
DROP TABLE IF EXISTS lote;
DROP TABLE IF EXISTS deposito;
DROP VIEW  IF EXISTS control_lote_almacen_compat;

CREATE TABLE deposito (
    id         BIGINT       NOT NULL,
    nombre     VARCHAR(80)  NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_deposito PRIMARY KEY (id)
);

CREATE TABLE lote (
    id          BIGINT       NOT NULL,
    descripcion VARCHAR(200) NOT NULL,
    proveedor   VARCHAR(80),
    creado_en   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_lote PRIMARY KEY (id)
);

CREATE TABLE usuario (
    id         BIGINT       NOT NULL,
    nombre     VARCHAR(80)  NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_usuario PRIMARY KEY (id)
);

-- ============================================================
-- ESQUEMA ORIGINAL (pre-descomposición)
-- ============================================================
CREATE TABLE control_lote_almacen (
    lote_id             BIGINT NOT NULL REFERENCES lote (id)     ON DELETE RESTRICT,
    deposito_id         BIGINT NOT NULL REFERENCES deposito (id) ON DELETE RESTRICT,
    responsable_control_id BIGINT NOT NULL REFERENCES usuario (id) ON DELETE RESTRICT,
    CONSTRAINT pk_control_lote_almacen PRIMARY KEY (lote_id, deposito_id)
);

-- ------------------------------------------------------------
-- Instancia de ejemplo (la del enunciado) y las maestras que la
-- sostienen.
--
-- usuario 803 y lote 504 se cargan a propósito SIN asignación:
-- son los que hacen visibles las anomalías de inserción y de
-- borrado. Si la relación contuviera todos los datos de las
-- maestras, las anomalías existirían pero no se podrían mostrar.
-- ------------------------------------------------------------
INSERT INTO deposito (id, nombre) VALUES
 (30, 'Depósito Norte'),
 (31, 'Depósito Sur');

INSERT INTO lote (id, descripcion, proveedor) VALUES
 (501, 'Lote de salame 12 x 1 kg',      'Granja del Sur'),
 (502, 'Lote de fainá 500 g',            'Granja del Sur'),
 (503, 'Lote de queso 12 u/paquete',     'Lácteos del Plata'),
 (504, 'Lote de limones recibido, sin asignar', 'Frutas Sur');

INSERT INTO usuario (id, nombre) VALUES
 (801, 'García, Marta'),
 (802, 'Pérez, Javier'),
 (803, 'Romero, Analía');   -- el último, sin asignación todavía

-- La instancia que da el enunciado:
INSERT INTO control_lote_almacen VALUES
 (501, 30, 801),
 (502, 30, 801),
 (503, 31, 802);

-- ============================================================
-- (d) LAS TRES ANOMALÍAS, DEMOSTRADAS CON SQL
--
-- Se ejecutan dentro de savepoints que se revierten: la base queda
-- con la instancia original. (Un BEGIN/ROLLBACK anidado no serviría:
-- en PostgreSQL el ROLLBACK innermost revierte la transacción
-- COMPLETA, y se perderían las tablas recién creadas.)
-- ============================================================

\echo ''
\echo '=== ANOMALÍA 1 — INSERCIÓN: no se puede dar de alta a un responsable sin inventar un lote ==='
-- Quien lee el turno de un depósito necesita saber que el usuario
-- 803 pertenece al depósito 31. Con este esquema el único lugar
-- donde se puede anotar es la fila de control de un lote, así que
-- hay que escribir un lote que no controla.
SAVEPOINT demo_insercion;
INSERT INTO control_lote_almacen VALUES (504, 31, 803);
SELECT * FROM control_lote_almacen ORDER BY lote_id;
ROLLBACK TO SAVEPOINT demo_insercion;

\echo ''
\echo '=== ANOMALÍA 2 — BORRADO: al cerrar una asignación se borra el depósito del responsable ==='
-- 802 sólo controla el lote 503. Dar de baja esa asignación elimina
-- el único registro que decía que 802 pertenece al depósito 31.
SAVEPOINT demo_borrado;
SELECT responsable_control_id, deposito_id FROM control_lote_almacen WHERE responsable_control_id = 802;
DELETE FROM control_lote_almacen WHERE lote_id = 503;
SELECT count(*) AS surviving_rows_about_user_802
  FROM control_lote_almacen WHERE responsable_control_id = 802;
ROLLBACK TO SAVEPOINT demo_borrado;

\echo ''
\echo '=== ANOMALÍA 3 — ACTUALIZACIÓN: un traslado de depósito exige tocar todas las filas, y si se hace a medias el mismo responsable queda en dos depósitos ==='
-- Marta García (801) pasa del depósito 30 al 31. Como el depósito
-- es parte de la clave primaria, "actualizar" es borrar una fila e
-- insertar otra: no es una operación de una sola sentencia y
-- ningún trigger la hace por nosotros. Si se aplica sobre el lote
-- 501 solamente, 801 queda controlando en los dos depósitos, que es
-- justo lo que la regla prohíbe.
SAVEPOINT demo_actualizacion;
DELETE FROM control_lote_almacen WHERE lote_id = 502 AND deposito_id = 30;
INSERT INTO control_lote_almacen VALUES (502, 31, 801);
SELECT responsable_control_id,
       count(DISTINCT deposito_id) AS depositos_al_que_pertenece
  FROM control_lote_almacen
 GROUP BY responsable_control_id
HAVING count(DISTINCT deposito_id) > 1;
ROLLBACK TO SAVEPOINT demo_actualizacion;

-- ============================================================
-- (e) DESCOMPOSICIÓN EN FNBC
--
-- Se viola FD2: ResponsableControlID -> DepositoID.
--
-- Algoritmo de descomposición sin pérdida (Silberschatz):
--   r1 = X  ∪  Y          (contiene la DF que se separa)
--   r2 = r  \  Y          (se le quita el atributo dependiente,
--                          que ya vive en r1)
--
-- Con X = {ResponsableControlID} e Y = {DepositoID}:
--   r1 = {ResponsableControlID, DepositoID}
--   r2 = {LoteID, ResponsableControlID}    (r menos DepositoID)
--
-- r1: FD2 con determinante = clave primaria  -> FNBC.
-- r2: sobre {LoteID, ResponsableControlID} no queda ninguna DF no
--     trivial (FD1 ya no proyecta: le falta DepositoID) -> FNBC.
--
-- ADVERTENCIA (F-U4-4, code review de la segunda entrega): la
-- variante "natural" r1 = {Resp, Dep} + r2 = {Lote, Dep} también
-- queda en FNBC, PERO se reúne por DepositoID, que NO es superclave
-- de ninguna de las dos ({DepositoID}+ = {DepositoID}): esa reunión
-- es CON PÉRDIDA. El contraejemplo del final de este script la
-- exhibe con datos. Por eso r2 se lleva ResponsableControlID y no
-- DepositoID: el atributo común de la reunión pasa a ser
-- ResponsableControlID, que sí es clave de r1.
-- ============================================================

CREATE TABLE responsable_deposito (
    responsable_control_id BIGINT NOT NULL REFERENCES usuario (id)   ON DELETE RESTRICT,
    deposito_id            BIGINT NOT NULL REFERENCES deposito (id) ON DELETE RESTRICT,
    created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- El dato maestro "cada responsable pertenece a un único
    -- depósito" queda REPRESENTADO por la clave primaria: la
    -- unicidad ya no depende de que nadie se acuerde de mantenerla.
    CONSTRAINT pk_responsable_deposito PRIMARY KEY (responsable_control_id),
    CONSTRAINT uq_responsable_deposito_deposito UNIQUE (deposito_id, responsable_control_id)
);

CREATE TABLE control_lote (
    lote_id                BIGINT NOT NULL REFERENCES lote (id)     ON DELETE RESTRICT,
    responsable_control_id BIGINT NOT NULL REFERENCES usuario (id)  ON DELETE RESTRICT,
    created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT pk_control_lote PRIMARY KEY (lote_id, responsable_control_id)
);
-- Nota: control_lote NO lleva deposito_id. El depósito se recupera
-- por la reunión con responsable_deposito sobre ResponsableControlID
-- —clave de esa tabla—, y ésa es exactamente la condición que hace
-- la reunión sin pérdida.
-- Contrapartida declarada: FD1 ({LoteID, DepositoID} ->
-- ResponsableControlID) deja de ser una restricción de esquema; se
-- detecta con la consulta inyectiva del final del script.

-- Índice de apoyo para la ruta inversa (qué lotes controla cada
-- responsable) y para que la vista filtre por responsable sin
-- recorrer la tabla.
CREATE INDEX ix_control_lote_responsable ON control_lote (responsable_control_id);

-- ============================================================
-- (f) MIGRACIÓN DE LOS DATOS Y VERIFICACIÓN
--
-- Antes de migrar se comprueba que la DF2 se cumpla realmente en
-- los datos heredados. El DISTINCT que usa el INSERT de abajo
-- resolvería en silencio un responsable repartido entre dos
-- depósitos y produciría una asignación equivocada; por eso el
-- control previo aborta si encuentra ese caso.
-- ============================================================
DO $$
DECLARE
    v_inconsistentes INT;
BEGIN
    SELECT count(*) INTO v_inconsistentes
      FROM (
        SELECT responsable_control_id
          FROM control_lote_almacen
         GROUP BY responsable_control_id
        HAVING count(DISTINCT deposito_id) > 1
      ) inconsistentes;

    IF v_inconsistentes > 0 THEN
        RAISE EXCEPTION
            'migración abortada: % responsable(s) controlan en más de un depósito; la DF2 no se cumple en los datos',
            v_inconsistentes;
    END IF;
END;
$$;

INSERT INTO responsable_deposito (responsable_control_id, deposito_id)
SELECT DISTINCT responsable_control_id, deposito_id
  FROM control_lote_almacen;

-- Distinto es seguro acá: bajo la FD2 que se acaba de verificar, un
-- mismo par (lote, responsable) no puede aparecer dos veces (eso
-- exigiría al responsable en dos depósitos), así que el DISTINCT no
-- colapsa nada.
INSERT INTO control_lote (lote_id, responsable_control_id)
SELECT DISTINCT lote_id, responsable_control_id
  FROM control_lote_almacen;

-- ============================================================
-- VISTA DE COMPATIBILIDAD
--
-- Reconstruye la relación original por reunión natural sobre
-- ResponsableControlID, el atributo común de las dos relaciones
-- descompuestas y clave primaria de responsable_deposito: ésa es
-- la condición del teorema que hace la reunión sin pérdida.
-- ============================================================
CREATE VIEW control_lote_almacen_compat AS
SELECT cl.lote_id,
       rd.deposito_id,
       cl.responsable_control_id
  FROM control_lote cl
  JOIN responsable_deposito rd
    ON rd.responsable_control_id = cl.responsable_control_id;

-- Equivalencia: la vista debe reproducir la relación original, en
-- las dos direcciones. Se espera 0 filas en cada lado.
SELECT 'solo_en_original' AS diferencia, o.*
  FROM control_lote_almacen o
 EXCEPT ALL
 SELECT 'solo_en_original', v.* FROM control_lote_almacen_compat v;

SELECT 'solo_en_la_vista' AS diferencia, v.*
  FROM control_lote_almacen_compat v
 EXCEPT ALL
 SELECT 'solo_en_la_vista', o.* FROM control_lote_almacen o;

-- Y que la vista devuelva la instancia de ejemplo del enunciado.
SELECT * FROM control_lote_almacen_compat ORDER BY lote_id;

-- Las dos relaciones descompuestas, por separado.
SELECT * FROM responsable_deposito ORDER BY responsable_control_id;
SELECT * FROM control_lote           ORDER BY lote_id;

-- El problema ya no es representable: en el esquema descompuesto no
-- se puede tener un responsable en dos depósitos, porque
-- responsable_control_id es clave primaria de su tabla. (Debe dar
-- 0 filas.)
SELECT responsable_control_id, count(*) AS veces
  FROM responsable_deposito
 GROUP BY responsable_control_id
HAVING count(*) > 1;

COMMIT;

-- ============================================================
-- POR QUÉ LA REUNIÓN ES SIN PÉRDIDA — Y CÓMO SE COMPRUEBA
--
-- Criterio de superclave sobre el atributo común. En la
-- descomposición r = r1 ⋈ r2 el atributo común es
--     r1 ∩ r2 = {ResponsableControlID}
--
-- Teorema: r1 ⋈ r2 sobre el atributo común es SIN PÉRDIDA si ese
-- atributo es superclave de AL MENOS UNA de las dos relaciones.
--
-- Aquí ResponsableControlID es la clave primaria de
-- responsable_deposito (r1) — y por FD2 determina todo r1 —, o sea
-- superclave de r1. Por lo tanto responsable_deposito ⋈ control_lote
-- es sin pérdida:
--   * no MULTIPLICA: cada responsable aparece una sola vez en r1,
--     así que cada fila de control_lote encuentra exactamente una
--     fila pareja;
--   * no PIERDE: cada par (lote, responsable) de r2 recupera su
--     depósito en r1.
--
-- Prueba empírica de la ausencia de pérdida y de tuplas espurias,
-- con el criterio de conteos y de suma de una clave surrogada:
--
--   original      3 filas
--   vista         3 filas
--   cardinalidad y suma de (lote_id*1000000 + deposito_id*1000 +
--   responsable_control_id) idénticas en ambos lados, y el EXCEPT
--   ALL de las dos direcciones da 0 filas.
-- ============================================================
SELECT 'original' AS lado, count(*) AS filas FROM control_lote_almacen
UNION ALL
SELECT 'vista', count(*) FROM control_lote_almacen_compat;

SELECT 'original' AS lado,
       sum(lote_id * 1000000 + deposito_id * 1000 + responsable_control_id) AS firma
  FROM control_lote_almacen
UNION ALL
SELECT 'vista',
       sum(lote_id * 1000000 + deposito_id * 1000 + responsable_control_id)
  FROM control_lote_almacen_compat;

-- Inyectividad de la vista sobre (lote_id, deposito_id): debe dar
-- 0 filas. Es además el DETECTOR DE VIOLACIONES DE FD1: como la
-- descomposición en FNBC no preserva {LoteID, DepositoID} ->
-- ResponsableControlID (control_lote ya no tiene deposito_id), un
-- mismo lote controlado por dos responsables del MISMO depósito no
-- lo detiene ninguna restricción de esquema; esta consulta es la
-- que lo hace visible. Si devuelve filas, hay que deshacer la
-- asignación o volver a la síntesis 3FN.
SELECT lote_id, deposito_id, count(*) AS veces
  FROM control_lote_almacen_compat
 GROUP BY lote_id, deposito_id
HAVING count(*) > 1;

-- ============================================================
-- CONTRAEJEMPLO: LA VARIANTE DESCARTADA ERA CON PÉRDIDA (F-U4-4)
--
-- La primera versión de este script descomponía en
--   r1 = responsable_deposito(Resp, Dep)
--   r2 = control_lote(Lote, Dep)
-- y reunía por DepositoID. Como {DepositoID}+ = {DepositoID} no es
-- superclave de NINGUNA de las dos relaciones, esa reunión es CON
-- PÉRDIDA. Se reproduce el contraejemplo mínimo con tablas
-- temporales: dos lotes controlados en el depósito 30 por dos
-- responsables distintos, ambos del depósito 30.
--
--   original (consistente con FD1 y FD2):
--       (501, 30, 801)  y  (502, 30, 803)          -> 2 filas
--   variante descartada, reunión por deposito_id     -> 4 filas
--       aparecen (501,30,803) y (502,30,801): cada lote "hereda"
--       al responsable del otro lote. Tuplas espurias.
--   variante implementada, reunión por responsable   -> 2 filas
--       exactamente las del original.
--
-- La prueba de la instancia del enunciado (un responsable por
-- depósito) NO distingue las dos variantes: por eso un EXCEPT ALL
-- 0/0 sobre esa instancia no es prueba de nada, y este
-- contraejemplo sí.
-- ============================================================
CREATE TEMP TABLE _demo_resp_dep  (responsable_control_id BIGINT, deposito_id BIGINT);
CREATE TEMP TABLE _demo_lote_dep (lote_id BIGINT, deposito_id BIGINT);
CREATE TEMP TABLE _demo_lote_resp (lote_id BIGINT, responsable_control_id BIGINT);

INSERT INTO _demo_resp_dep  VALUES (801, 30), (803, 30);
INSERT INTO _demo_lote_dep VALUES (501, 30), (502, 30);
INSERT INTO _demo_lote_resp VALUES (501, 801), (502, 803);

\echo ''
\echo '=== CONTRAEJEMPLO F-U4-4: reunion por deposito_id (variante DESCARTADA) ==='
\echo '=== filas_variante_descartada debe dar 4; el original tiene 2           ==='
SELECT count(*) AS filas_variante_descartada
  FROM _demo_lote_dep ld
  JOIN _demo_resp_dep rd ON rd.deposito_id = ld.deposito_id;

\echo ''
\echo '=== reunion por responsable_control_id (variante IMPLEMENTADA) ==='
\echo '=== filas debe dar 2: exactamente las del original             ==='
SELECT count(*) AS filas_variante_implementada
  FROM _demo_lote_resp lr
  JOIN _demo_resp_dep rd ON rd.responsable_control_id = lr.responsable_control_id;

DROP TABLE _demo_resp_dep, _demo_lote_dep, _demo_lote_resp;

-- ============================================================
-- REVERSIBILIDAD DE LA DESCOMPOSICIÓN
--
-- Perder la vista y las tablas descompuestas no es perder datos:
-- la relación original se conserva íntegra y
--
--   DROP VIEW control_lote_almacen_compat;
--   DROP TABLE control_lote;
--   DROP TABLE responsable_deposito;
--
-- devuelve el esquema al estado previo. Al revés, la relación
-- original se reconstruye desde las dos tablas con el mismo
-- SELECT de la vista de compatibilidad (por eso la vista es
-- "de compatibilidad": sirve para leer y para rehacer).
-- ============================================================