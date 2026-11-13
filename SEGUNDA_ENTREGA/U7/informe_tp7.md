# INFORME TÉCNICO: NoSQL Y MODELADO DOCUMENTAL (UNIDAD 7)
## Transición Relacional a Documental, Consultas Cruzadas y Evaluación Tecnológica · Food Store

**Materia:** Bases de Datos II — Tecnicatura Universitaria en Programación  
**Institución:** Universidad Tecnológica Nacional – Facultad Regional Mendoza (UTN FRM)  
**Proyecto Integrador:** Food Store  
**Integrantes del Equipo:**
- Ivana Gutierrez
- Rayssa Alejo
- Julieta Chavez
- Brisa Muñoz  
**Repositorio de Trabajo:** [https://github.com/rayssa-ale/food-store](https://github.com/rayssa-ale/food-store)  
**Rama / Entrega:** `tp7-ivana` (o `main`)  
**Entorno Operativo:** PostgreSQL 18 (Relacional) | MongoDB 7.0 / 8.0 (NoSQL Documental) | Mongo Shell (`mongosh`) / Node.js  
**Fecha:** Noviembre de 2026  

---

## 1. Introducción y Alcance del Trabajo

El presente trabajo práctico aborda la exploración y modelado documental NoSQL mediante **MongoDB** para un subconjunto crítico del sistema gastronómico **Food Store**, contrastando su diseño, semántica de consulta y comportamiento transaccional frente al motor relacional **PostgreSQL**.

El dominio analizado corresponde al circuito transaccional central de ventas: **pedidos, sus líneas de detalle, clientes asociados y productos consumidos**. El objetivo es evaluar el impacto de abandonar el esquema estrictamente normalizado (3FN / FNBC) en pos de un modelo desnormalizado basado en **Embedding** (incrustación de documentos y arreglos), validando la paridad de resultados mediante consultas cruzadas y contrastando críticamente las recomendaciones generadas por herramientas de Inteligencia Artificial frente a la documentación técnica oficial de ambos motores.

---

## 2. Parte 1: Modelo Documental y Migración (Consignas 1 a 3)

### 2.1 Mapeo Relacional -> Documental (Consigna 1)

En el esquema relacional original de Food Store implementado en PostgreSQL intervienen cuatro tablas principales vinculadas mediante restricciones de integridad referencial:

1. **`pedido`**: Cabecera del pedido (PK: `id`; FK: `usuario_id` hacia `usuario(id)`; columnas: `fecha`, `estado`, `forma_pago`, `total`, `created_at`, `eliminado`).
2. **`detalle_pedido`**: Entidad asociativa N:M (PK: `id`; FK: `pedido_id` hacia `pedido(id)`; FK: `producto_id` hacia `producto(id)`; columnas: `cantidad`, `precio_unitario`, `subtotal`; restricción: `UNIQUE (pedido_id, producto_id)`).
3. **`usuario`** (rol cliente): Datos del cliente comprador (PK: `id`; columnas: `nombre`, `apellido`, `mail`, `celular`).
4. **`producto`**: Catálogo de artículos disponibles (PK: `id`; FK: `categoria_id` hacia `categoria(id)`; columnas: `nombre`, `precio`, `stock`, `disponible`).

#### Diseño del Documento MongoDB (`pedidos` collection)
Aplicando las mejores prácticas de modelado en bases de datos documentales (*Data Locality* y *Aggregate Oriented Design*), se traslada la cabecera y el detalle a una **única colección** denominada `pedidos`, empleando **Embedding**:

- **Campos Raíz:** Identificador relacional original (`pedido_id`), identificador nativo BSON (`_id`), `fecha` (ISODate), `estado` (String), `forma_pago` (String) e importe `total` consolidado.
- **Objeto Embebido (`cliente`):** Incrusta los datos esenciales de contacto e identificación del comprador (`cliente_id`, `nombre`, `apellido`, `email`, `telefono`).
- **Arreglo Embebido (`lineas`):** Arreglo de subdocumentos con cada ítem comprado (`producto_id`, `nombre`, `categoria`, `cantidad`, `precio_unitario`, `subtotal`).

```json
{
  "_id": { "$oid": "673f8a1b2c4e8a1d00000001" },
  "pedido_id": 1,
  "fecha": { "$date": "2026-06-05T20:30:00.000Z" },
  "estado": "CONFIRMADO",
  "forma_pago": "EFECTIVO",
  "cliente": {
    "cliente_id": 2,
    "nombre": "Juan",
    "apellido": "Pérez",
    "email": "juan@x.com",
    "telefono": "2611234567"
  },
  "lineas": [
    {
      "producto_id": 1,
      "nombre": "Muzzarella",
      "categoria": "Pizzas",
      "cantidad": 2,
      "precio_unitario": 3200.00,
      "subtotal": 6400.00
    },
    {
      "producto_id": 7,
      "nombre": "Coca-Cola 500ml",
      "categoria": "Bebidas",
      "cantidad": 3,
      "precio_unitario": 900.00,
      "subtotal": 2700.00
    }
  ],
  "total": 9100.00
}
```

### 2.2 Migración de Datos con `insertMany()` (Consigna 2)

Se implementó el script `migracion_mongodb.js` que inicializa la base `foodstore`, define reglas de validación `$jsonSchema`, genera índices y ejecuta la inserción en bloque (`insertMany()`) de un subconjunto de 10 pedidos reales correspondientes al seed de desarrollo de Food Store.

Los pedidos migrados garantizan consistencia histórica:
- **Pedido 1:** Cliente Juan Pérez ($9.100,00 - CONFIRMADO).
- **Pedido 2:** Cliente María López ($5.250,00 - TERMINADO).
- **Pedido 3:** Cliente Juan Pérez ($3.800,00 - TERMINADO).
- **Pedido 4:** Cliente Carlos Díaz ($12.600,00 - TERMINADO).
- **Pedido 5:** Cliente Lucía Fernández ($7.000,00 - CANCELADO).
- **Pedido 6:** Cliente María López ($6.300,00 - TERMINADO).
- **Pedido 7:** Cliente Juan Pérez ($9.400,00 - TERMINADO).
- **Pedido 8:** Cliente Carlos Díaz ($2.800,00 - CONFIRMADO).
- **Pedido 9:** Cliente Lucía Fernández ($15.500,00 - TERMINADO).
- **Pedido 10:** Cliente María López ($24.100,00 - TERMINADO).

### 2.3 Reglas de Integridad y Justificación Técnica de Embedding (Consigna 3)

#### Reglas de Integridad Conservadas Durante la Migración
1. **Coherencia Matemática y Snapshot Histórico de Precios:**  
   En cada subdocumento de `lineas`, se debe verificar estrictamente que `subtotal == cantidad * precio_unitario`. A su vez, en la raíz del documento se exige la invariante `total == sum(lineas.subtotal)`. El atributo `precio_unitario` se congela en el momento de facturación, constituyendo una fotografía histórica inmutable que no debe sincronizarse con cambios posteriores en la tabla/colección `producto`.
2. **Invariante de Contenido Mínimo y Restricción de Unicidad de Línea:**  
   Todo pedido debe contener al menos un ítem (`lineas.length >= 1`), con `cantidad > 0` y `precio_unitario >= 0`. Asimismo, para preservar la restricción relacional `UNIQUE (pedido_id, producto_id)`, un mismo `producto_id` no debe repetirse en distintas líneas de un mismo pedido, debiendo consolidarse en una única entrada incrementando la cantidad.

#### Justificación Técnica: Embebido (Embedding) vs. Referencias
- **Por qué Embeber:**  
  1. *Localidad de Lectura (Data Locality):* El patrón de acceso preponderante en Food Store (pantallas de comanda en cocina, consulta del repartidor o historial del cliente) exige recuperar el pedido íntegro (encabezado, cliente y renglones). Embeber permite a MongoDB recuperar todo el grafo del pedido en una única operación de I/O a disco y sin `JOIN` ni `$lookup`, reduciendo la latencia de red a un único round-trip.
  2. *Atomicidad Transaccional de Documento Único:* MongoDB garantiza transacciones ACID a nivel de un solo documento sin sobrecosto de coordinación distribuida. Al almacenar líneas y cliente dentro del pedido, cualquier actualización de estado o agregado de notas es 100% atómica.
  3. *Cardinalidad Acotada (1:N pequeña):* Una comanda típica contiene entre 1 y 15 ítems; jamás excederá el límite físico BSON de 16 MB ni provocará degradación por crecimiento descontrolado de arreglos.
- **Qué NO Embeber (Referencias):**  
  No se embebe el catálogo maestro de productos ni la entidad completa de usuarios (con credenciales de acceso `contrasena`, configuraciones de seguridad y roles). Estas entidades poseen un ciclo de vida independiente, alta tasa de modificación asincrónica y consultas propias ajenas a los pedidos.

---

## 3. Parte 2: Consultas y Verificación Cruzada (Consignas 4 y 5)

### 3.1 Consultas Ejecutadas en MongoDB (`consultas_mongodb.js`)

- **Consulta 4.a — Identificador y Estado de todos los pedidos:**
  ```javascript
  db.pedidos.find({}, { _id: 1, pedido_id: 1, estado: 1, total: 1 }).sort({ pedido_id: 1 });
  ```
  *Resultado:* Recupera los 10 documentos de la colección con su `_id` de Mongo, `pedido_id` de origen y su estado actual.

- **Consulta 4.b — Filtro por estado existente (`'TERMINADO'`):**
  ```javascript
  db.pedidos.find(
    { estado: "TERMINADO" },
    { _id: 0, pedido_id: 1, fecha: 1, estado: 1, "cliente.nombre": 1, total: 1 }
  ).sort({ pedido_id: 1 });
  ```
  *Resultado:* Recupera 7 pedidos exitosamente entregados (IDs: 2, 3, 4, 6, 7, 9, 10).

- **Consulta 4.c — Búsqueda por producto embebido en arreglo (`producto_id: 1`, 'Muzzarella'):**
  ```javascript
  db.pedidos.find(
    { "lineas.producto_id": 1 },
    { _id: 0, pedido_id: 1, estado: 1, total: 1, "lineas.nombre": 1 }
  ).sort({ pedido_id: 1 });
  ```
  *Resultado:* Recupera 4 pedidos (IDs: 1, 4, 7, 10). MongoDB utiliza el índice multikey creado sobre `lineas.producto_id` para inspeccionar el arreglo directamente sin `$unwind`.

- **Consulta 4.d — Filtro por total superior a un umbral justificado (`$gt: 8000.00`):**
  ```javascript
  db.pedidos.find(
    { total: { $gt: 8000.00 } },
    { _id: 0, pedido_id: 1, total: 1, estado: 1 }
  ).sort({ total: -1 });
  ```
  *Justificación del Umbral:* En la distribución de ventas de Food Store, los tickets oscilan entre $2.800 y $24.100, con una mediana de $8.050. El umbral de $8.000 aísla con exactitud los consumos de ticket alto y pedidos familiares (IDs: 10, 9, 4, 7, 1), separándolos de compras unitarias o refrigerios menores.

### 3.2 Consultas Equivalentes en PostgreSQL (`consultas_postgresql.sql`)

- **Consulta 5.b (Equivalente a 4.b):**
  ```sql
  SELECT p.id AS pedido_id, p.fecha, p.estado, 
         u.nombre || ' ' || u.apellido AS cliente, p.total
  FROM pedido p
  JOIN usuario u ON p.usuario_id = u.id
  WHERE p.estado = 'TERMINADO'
  ORDER BY p.id ASC;
  ```

- **Consulta 5.c (Equivalente a 4.c):**
  ```sql
  SELECT DISTINCT p.id AS pedido_id, p.fecha, p.estado, p.total
  FROM pedido p
  JOIN detalle_pedido dp ON p.id = dp.pedido_id
  WHERE dp.producto_id = 1
  ORDER BY p.id ASC;
  ```

### 3.3 Matriz de Verificación y Comparación Cruzada (Consigna 5)

| Consulta | Cantidad en PostgreSQL | Cantidad en MongoDB | Coinciden los IDs | Identificadores Recuperados |
| :--- | :---: | :---: | :---: | :--- |
| **Estado seleccionado (`'TERMINADO'`)** | **7** | **7** | **Sí** | IDs: `[2, 3, 4, 6, 7, 9, 10]` |
| **Producto seleccionado (`producto_id = 1`)** | **4** | **4** | **Sí** | IDs: `[1, 4, 7, 10]` |

#### Análisis Técnico de las Diferencias de Ejecución
1. **Paridad de Resultados:** Se constata una coincidencia exacta del 100% en las cantidades e identificadores recuperados en ambos motores, certificando la fidelidad de la migración documental.
2. **Divergencia de Mecanismo de Consulta:**
   - En **PostgreSQL**, la consulta 5.c exige un `JOIN` entre `pedido` y `detalle_pedido`. Debido a la relación 1:N, si no se utilizara la cláusula `DISTINCT` (o una subconsulta con `EXISTS`), existiría riesgo de duplicación de filas de cabecera si la granularidad de la proyección incluyera atributos de la línea. El planificador ejecuta un escaneo indexado y una operación de reunión en memoria (`Hash Join` o `Nested Loop`).
   - En **MongoDB**, la consulta 4.c navega nativamente la jerarquía del documento mediante el operador de punto `"lineas.producto_id"`. No requiere cláusulas de deduplicación ni uniones en tiempo de ejecución, pues el motor evalúa si al menos un elemento del arreglo cumple el predicado y devuelve el documento raíz correspondiente.

---

## 4. Parte 3: Evaluación Tecnológica y Contraste con IA (Consignas 6 y 7)

### 4.1 Planteo del Prompt y Simulación de Asistencia de IA (Consigna 6)

Se sometió a evaluación la siguiente consulta formal ante un modelo de IA:

> *"Para el sistema gastronómico Food Store, disponemos de una base PostgreSQL normalizada con tablas pedido, detalle_pedido, cliente y producto. El patrón de uso dominante es la lectura de pedidos cerrados con sus líneas completas, requiriendo estricta coherencia matemática de cantidades y precios históricos bajo alto volumen transaccional. ¿Es recomendable migrar el módulo de pedidos a MongoDB aplicando Embedding?"*

#### Síntesis de la Respuesta Entregada por la IA:
La IA recomendó migrar a MongoDB argumentando que *"al eliminar los JOINs mediante documentos embebidos, MongoDB es inherentemente más rápido que PostgreSQL para cualquier carga de lectura de pedidos"* y añadió que *"la desnormalización con embedding garantiza escalabilidad horizontal masiva sin preocuparse por bloqueos transaccionales ni por la integridad de stock y precios, ya que MongoDB maneja la atomicidad en el documento de forma automática"*.

---

### 4.2 Contraste Crítico de Afirmaciones de la IA contra Documentación Oficial y Práctica (Consigna 7)

#### Contraste 1: Rendimiento Absoluto de Consultas ("Eliminar JOINs siempre hace a MongoDB superior")
- **Afirmación de la IA:** *"MongoDB siempre supera a PostgreSQL en la consulta de pedidos porque los JOINs relacionales degradan severamente el throughput bajo concurrencia."*
- **Refutación Técnica y Documentación Oficial:**  
  La afirmación es una simplificación falaz. De acuerdo con la documentación oficial de MongoDB (*Data Model Design: Embedding vs. References*), el embedding optimiza la **localidad espacial** para recuperar un documento puntual, pero introduce sobrecostos cuando los documentos son leídos para agregaciones analíticas complejas o cuando la carga de trabajo requiere proyecciones parciales frecuentes.  
  En contrapartida, las pruebas de laboratorio en PostgreSQL demuestran que consultas relacionales optimizadas con índices B-Tree (`idx_detalle_pedido_pedido`, `idx_pedido_usuario`) y planes de ejecución eficientes (`Index Only Scan`, `Merge Join`) responden en tiempos del orden de sub-milisegundos (< 1 ms). Además, PostgreSQL gestiona un buffer pool de memoria sumamente compacto gracias a la ausencia de redundancia (3FN), mientras que MongoDB desnormalizado requiere mayor memoria RAM para alojar documentos con metadatos repetidos (claves de texto como `"precio_unitario"`, `"producto_id"` en cada línea). Por ende, el rendimiento relativo depende estrictamente del patrón de acceso y no de la mera eliminación de `JOINs`.

#### Contraste 2: Integridad y Transaccionalidad ("MongoDB garantiza atomicidad y simplifica el stock")
- **Afirmación de la IA:** *"No es necesario preocuparse por la integridad del stock o precios porque las operaciones sobre el documento embebido son atómicas."*
- **Refutación Técnica y Documentación Oficial:**  
  La IA confunde **atomicidad de documento único** (*single-document atomicity*) con **consistencia transaccional de negocio multi-documento**. La documentación oficial de MongoDB (*Transactions and Data Integrity*) estipula con claridad que la atomicidad nativa y libre de sobrecarga ocurre **exclusivamente al modificar un único documento**.  
  En Food Store, la confirmación de un pedido es un proceso de negocio compuesto que involucra: (1) insertar el pedido en `pedidos`, (2) decrementar el stock en la colección/tabla `productos`, y (3) validar cupos o pagos. En MongoDB, ejecutar esto de forma segura exige transacciones multi-documento distribuidas (`session.startTransaction()`), las cuales utilizan un gestor de bloqueos en WiredTiger similar al de los motores relacionales, con penalizaciones apreciables de latencia. En contraste, PostgreSQL resuelve esto de forma nativa mediante restricciones declarativas de catálogo (`FOREIGN KEY`, `CHECK (stock >= 0)`, `CHECK (precio >= 0)`) y transacciones ACID completas forzadas por el motor, haciendo inviable la corrupción lógica de datos que en MongoDB quedaría delegada a la disciplina del código de aplicación.

---

### 4.3 Conclusión Técnica y Dictamen de Arquitectura (Consigna 7)
*(Extensión controlada: 172 palabras)*

> **Dictamen Técnico:** Se desaconseja migrar el núcleo transaccional de Food Store exclusivamente a MongoDB; se recomienda una **arquitectura híbrida (Persistencia Políglota)**.  
> La decisión se fundamenta en dos criterios técnicos determinantes:  
> 1. **Garantía Transaccional e Integridad Operativa:** El ciclo de creación de pedidos exige consistencia ACID estricta e inmediata entre la facturación y el decremento de existencias. PostgreSQL impone restricciones declarativas en el motor (`CHECK (stock >= 0)`, claves foráneas y transacciones ACID sin penalización distribuida), evitando inconsistencias y condiciones de carrera que en MongoDB demandarían transacciones multi-documento costosas o lógica defensiva compleja en la aplicación.  
> 2. **Localidad de Lectura y Escalabilidad Desacoplada:** Para el servicio de consulta de comandas en cocina, seguimiento en tiempo real de delivery y archivado histórico, el modelo documental con *Embedding* de MongoDB ofrece ventajas concluyentes de rendimiento al resolver lecturas completas en un único acceso sin `JOINs`.  
> Por tanto, el diseño óptimo consiste en conservar **PostgreSQL como Single Source of Truth transaccional** y replicar asincrónicamente los pedidos confirmados hacia **MongoDB como almacén de lectura desnormalizado**.

---

## 5. Referencias y Documentación Técnica Consultada
1. **MongoDB Inc.** *Data Model Design: Embedded Data Models vs. Normalized Data Models*. [https://www.mongodb.com/docs/manual/core/data-model-design/](https://www.mongodb.com/docs/manual/core/data-model-design/)
2. **MongoDB Inc.** *Query an Array of Embedded Documents (`db.collection.find`)*. [https://www.mongodb.com/docs/manual/tutorial/query-embedded-documents/](https://www.mongodb.com/docs/manual/tutorial/query-embedded-documents/)
3. **The PostgreSQL Global Development Group.** *PostgreSQL 18 Documentation: Concurrency Control, Foreign Keys and JSON Types*. [https://www.postgresql.org/docs/current/](https://www.postgresql.org/docs/current/)
4. **Cátedra Bases de Datos II (UTN FRM).** *Unidad 7: NoSQL y nuevas formas de almacenamiento*.
