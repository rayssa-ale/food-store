# Declaración de Uso de IA (DUIA) — TP1 Food Store

**Materia:** Base de Datos I — Tecnicatura Universitaria en Programación a Distancia (UTN)
**Proyecto:** Food Store — TP1 (modelo ER, modelo relacional, normalización y DDL)

## Herramienta usada

- **OpenCode** (CLI de IA) con asistente del modelo *big-pickle*, como motor primario del trabajo, según lo exigido por la cátedra.
- **PostgreSQL 18** (instalado en la máquina local) para verificar la ejecución de `schema.sql`.
- **Microsoft Edge (headless)** para renderizar el diagrama Mermaid (HTML → PNG/PDF) y generar los PDF de entrega.
- **Python 3.13** (biblioteca estándar y Pillow) para validar el renderizado del diagrama (ausencia de errores de parseo de Mermaid).

## Para qué se usó y con qué prompts

| Parte | Uso de la IA | Prompts / especificación aplicados |
|---|---|---|
| Parte 1 (ER) | Identificar entidades, atributos, claves candidatas, cardinalidades y participación a partir de las reglas R1–R7 | "Modelá el dominio Food Store del enunciado; definí entidades, atributos conceptuales, claves y, para cada relación, cardinalidad y participación total/parcial justificada con la regla de negocio. Respondé las 3 preguntas guía." |
| Parte 2 (relacional) | Derivar las tablas con PK/FK, decidir la clave sustituta de la tabla intermedia y responder las preguntas guía | "Convertí el ER a modelo relacional: entidades a tablas, 1:N con FK en el lado N, N:M con tabla intermedia. Justificá la clave sustituta y respondé las 2 preguntas guía." |
| Parte 3 (normalización) | Desarrollar los 7 pasos (clave candidata, FDs, 1FN→2FN→3FN→BCNF) con las respuestas a las preguntas de integración | "Normalizá la planilla plana hasta BCNF, explicitando cada dependencia funcional: nro_pedido → fecha, cliente, forma_pago; producto → categoria; (nro_pedido, producto) → precio_unitario, cantidad, subtotal; precio_unitario × cantidad → subtotal. Mostrá el razonamiento paso a paso." |

## Revisión humana aplicada

- Cada script fue leído y defendido antes de ejecutarse (protocolo de la cátedra: copia, revisión de diff, ejecución controlada).
- El `schema.sql` se ejecutó sobre una base de pruebas local y se revisó la salida de PostgreSQL (verificación de creaciones y ausencia de errores).
- La resolución teórica (Partes 1, 2 y 3) vincula cada decisión con las reglas de negocio R1–R7 del enunciado.
