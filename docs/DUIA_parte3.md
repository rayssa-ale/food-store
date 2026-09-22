# DUIA — Parte 3: Ejercicio de lectura crítica (TP2 Food Store)

**Materia:** Base de Datos II — UTN · **Proyecto:** Food Store
**Tema:** Análisis de dos scripts SQL peligrosos (baja masiva sin WHERE
y DELETE con trampa de NULL en NOT IN) y sus correcciones.

## Herramientas usadas

| Herramienta | Uso |
|---|---|
| **OpenCode** (CLI de IA, modelo *big-pickle) | Asistencia para identificar los patrones de error (UPDATE sin filtro; lógica de tres valores del NULL en NOT IN) y proponer correcciones. |
| **PostgreSQL 18** (local) | Verificación de la lógica de las correcciones (NOT EXISTS vs NOT IN con NULL) **sobre la copia** `food_store_dev`, en caso de duda, dentro de transacciones reversibles. |
| **Git** | Versionado del ejercicio y la DUIA. |

## Para qué se usó la IA y con qué prompts

| Script | Uso de la IA | Prompt / especificación |
|---|---|---|
| `UPDATE funcion SET activa = FALSE` | Detectar que la intención (bajas de películas retiradas) no está expresada en la SQL y que falta todo filtro | «Este script debería dar de baja solo funciones de películas retiradas de cartel. Analizalo paso a paso: qué hace, por qué es peligroso y qué corrección hay que aplicar, con control antes de commitear» |
| `DELETE FROM categoria WHERE id NOT IN (SELECT categoria_id FROM producto)` | Explicar la trampa del NULL en NOT IN (lógica de tres valores) y la alternativa NOT EXISTS | «Explicá por qué este DELETE puede no borrar nada si categoria_id admite NULL, y mostrá la corrección con NOT EXISTS respetando la baja lógica (R7)» |

## Revisión humana aplicada

- La corrección NO se limitó a lo que la IA dictó: se cotejó contra
  el esquema real del Food Store. La que involucraba un DELETE físico
  sobre `categoria` se descartó en favor de baja lógica `activo = FALSE`
  (regla R7 del proyecto), decisión humana documentada en el ejercicio.
- Las dos soluciones quedan dentro del protocolo
  (protocolo_seguridad.md): copia + transacción + control de alcance
  antes del COMMIT.
- El documento incluye la lógica de tres valores del NULL, verificable
  en cualquier motor SQL, como conocimiento de la cátedra y no como
  afirmación aislada de la IA.