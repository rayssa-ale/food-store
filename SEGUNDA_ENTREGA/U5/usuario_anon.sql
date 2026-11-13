-- usuario_anon.sql - Parte D TP Unidad 5
-- Protección de datos personales: anonimización determinista de usuario
-- Ejecutar ÚNICAMENTE contra tu instancia local de desarrollo
-- Base objetivo: foodstore_test (food_Store existe pero está vacía: 0 filas)
-- Requiere: psql -v ON_ERROR_STOP=1 -f sql/usuario_anon.sql
--
-- Propiedades del patrón:
--   * Determinista: no usa random(), now(), gen_random_uuid() ni hashes del dato real.
--   * Idempotente: CREATE TABLE IF NOT EXISTS + TRUNCATE + INSERT ... SELECT.
--   * Atómico: todo ocurre dentro de una transacción.
--   * Solo agrega/reescribe public.usuario_anon; public.usuario es de solo lectura.
--
-- Cuasi-identificadores conservados de forma deliberada (documentados):
--   * id        -> se conserva como PK; permite joins y control de integridad.
--   * created_at-> truncado a mes; es la granularidad analítica solicitada.
-- La equivalencia con la tabla real es a nivel de agregados, no fila por fila.

\set ON_ERROR_STOP on

-- =====================================================
-- BLOQUE 1: CREACIÓN DE LA TABLA ANONIMIZADA
-- Mismos tipos y nulabilidad que las columnas conservadas.
-- rol mantiene el enum public.rol (NO text) para que los
-- agrupamientos sean comparables con la tabla original.
-- =====================================================
BEGIN;

CREATE TABLE IF NOT EXISTS public.usuario_anon (
    id         bigint                   NOT NULL,
    nombre     character varying(80)    NOT NULL,
    apellido   character varying(80)    NOT NULL,
    mail       character varying(120)   NOT NULL,
    celular    character varying(30),
    contrasena character varying(255)   NOT NULL,
    rol        public.rol               NOT NULL,
    eliminado  boolean                  NOT NULL,
    created_at timestamp with time zone NOT NULL,
    CONSTRAINT usuario_anon_pkey PRIMARY KEY (id)
);

COMMENT ON TABLE public.usuario_anon IS
    'Copia anonimizada de public.usuario. Reemplazo determinista de identificadores con utilidad analítica preservada (no es k-anonimidad ni anonimización diferencial).';
COMMENT ON COLUMN public.usuario_anon.id IS
    'Cuasi-identificador interno conservado como clave primaria.';
COMMENT ON COLUMN public.usuario_anon.created_at IS
    'Fecha de alta truncada a mes (date_trunc(''month'', ...)) como cuasi-identificador de baja granularidad.';
COMMENT ON COLUMN public.usuario_anon.contrasena IS
    'Marcador fijo ANONIMIZADO. Nunca contiene hashes ni contraseñas reales.';

-- =====================================================
-- BLOQUE 2: CARGA DETERMINISTA DE DATOS SINTÉTICOS
-- Cada valor sintético depende solo de id o es constante.
-- =====================================================
TRUNCATE TABLE public.usuario_anon;

INSERT INTO public.usuario_anon (
    id, nombre, apellido, mail, celular, contrasena, rol, eliminado, created_at
)
SELECT
    u.id,
    'Usuario ' || u.id                                   AS nombre,
    'Anonimo'                                            AS apellido,
    'user' || u.id || '@anon.invalid'                    AS mail,
    NULL                                                 AS celular,
    'ANONIMIZADO'                                        AS contrasena,
    u.rol,
    u.eliminado,
    date_trunc('month', u.created_at)                    AS created_at
FROM public.usuario AS u;

-- =====================================================
-- BLOQUE 3: RESTRICCIÓN DE ACCESO
-- Sin roles nuevos: se quita todo permiso a PUBLIC.
-- =====================================================
REVOKE ALL ON public.usuario_anon FROM PUBLIC;

COMMIT;

-- =====================================================
-- BLOQUE 4: VERIFICACIÓN
-- =====================================================
SELECT 'usuario_anon: filas cargadas' AS etapa, count(*) AS total FROM public.usuario_anon;
SELECT 'usuario_anon: mails duplicados' AS etapa, count(*) - count(DISTINCT mail) AS duplicados FROM public.usuario_anon;
