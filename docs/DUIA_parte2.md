# DUIA — Parte 2: Laboratorio de concurrencia (TP2 Food Store)

**Materia:** Base de Datos II — UTN · **Proyecto:** Food Store
**Tema:** Reproducir anomalías de concurrencia con dos sesiones,
explicación generada por IA y verificación en el motor.

## Herramientas usadas

| Herramienta | Uso |
|---|---|
| **OpenCode** (CLI de IA, modelo *big-pickle) | Predicción/explicación de cada anomalía y de la solución (por escenario). |
| **PostgreSQL 18** (local) | Motor donde se reprodujeron y verificaron los 4 escenarios (`food_store_dev`). |
| **Python 3.13 + psycopg2** | Control fino de dos sesiones concurrentes (inicio, pausas, captura de tiempos y SQLSTATE). |
| **Git** | Versionado del informe y la DUIA. |

## Para qué se usó la IA y con qué prompts

| Uso | Prompt / especificación aplicados |
|---|---|
| Predecir qué anomalía produce cada escenario y qué nivel de aislamiento la corrige | «En PostgreSQL, describí qué pasa con SELECT repetidos entre dos sesiones en READ COMMITTED vs REPEATABLE READ para precio (no repetible) y COUNT (fantasma); y qué pasa con FOR UPDATE cruzado (espera y 40P01). Explicá por qué el motor prefiere abortar una tx» |
| Redactar explicaciones por escenario | Se copiaron textuales en `docs/informe_concurrencia.md` y luego se **confrontaron con la salida real del motor**. |

## Verificación (regla del TP: la IA propone, el motor decide)

Cada explicación se confrontó con salidas reales:

1. **No repetible:** en READ COMMITTED el precio cambió 1200→1300; en
   REPEATABLE READ quedó estable (1300→1300). ✔
2. **Fantasma:** COUNT 2→3 en RC; estable (3→3) en RR. ✔
3. **Espera:** sesión B esperó **4,51 s** medidos hasta el COMMIT de A. ✔
4. **Interbloqueo:** `DeadlockDetected sqlstate=40P01` capturado; la otra
   sesión committeó. ✔

## Revisión humana aplicada

- Los 4 escenarios se ejecutaron sobre la copia `food_store_dev`
  (protocolo_seguridad.md), sin tocar datos productivos.
- Se validó la consistencia final de la base (precio p1 1200.00, stock
  p6 12, 2 líneas en pedido 1).
- Los tiempos y SQLSTATE del informe provienen del transcript del motor,
  no de la IA.