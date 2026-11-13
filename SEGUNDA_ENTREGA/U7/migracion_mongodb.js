/**
 * =============================================================================
 * SCRIPT: migracion_mongodb.js
 * MATERIA: Bases de Datos II — Tecnicatura Universitaria en Programación (UTN FRM)
 * UNIDAD 7: NoSQL y nuevas formas de almacenamiento | Food Store
 * =============================================================================
 * 
 * OBJETIVO:
 * Creación de la base de datos 'foodstore', inicialización de la colección 'pedidos',
 * creación de índices multikey y migración documental desnormalizada (Embedding)
 * de pedidos provenientes del modelo relacional PostgreSQL de Food Store.
 * 
 * EJECUCIÓN (Mongo Shell / mongosh):
 *   mongosh "mongodb://localhost:27017/foodstore" migracion_mongodb.js
 * =============================================================================
 */

// 1. Selección y aseguramiento de la base de datos
db = db.getSiblingDB("foodstore");

// 2. Limpieza preventiva de la colección para asegurar idempotencia
db.pedidos.drop();

// 3. Creación formal de la colección con validación JSON Schema (Opcional / Buenas prácticas)
db.createCollection("pedidos", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["pedido_id", "fecha", "estado", "forma_pago", "cliente", "lineas", "total"],
      properties: {
        pedido_id: {
          bsonType: "int",
          description: "Identificador original relacional de PostgreSQL (debe ser entero)"
        },
        fecha: {
          bsonType: "date",
          description: "Fecha y hora de emisión del pedido"
        },
        estado: {
          enum: ["PENDIENTE", "CONFIRMADO", "TERMINADO", "CANCELADO", "ENTREGADO"],
          description: "Estado del ciclo de vida del pedido"
        },
        forma_pago: {
          enum: ["EFECTIVO", "TARJETA", "TRANSFERENCIA"],
          description: "Método de pago del pedido"
        },
        cliente: {
          bsonType: "object",
          required: ["cliente_id", "nombre", "apellido", "email"],
          properties: {
            cliente_id: { bsonType: "int" },
            nombre: { bsonType: "string" },
            apellido: { bsonType: "string" },
            email: { bsonType: "string" },
            telefono: { bsonType: "string" }
          }
        },
        lineas: {
          bsonType: "array",
          minItems: 1,
          description: "Arreglo embebido de ítems del pedido (al menos uno)",
          items: {
            bsonType: "object",
            required: ["producto_id", "nombre", "cantidad", "precio_unitario", "subtotal"],
            properties: {
              producto_id: { bsonType: "int" },
              nombre: { bsonType: "string" },
              categoria: { bsonType: "string" },
              cantidad: { bsonType: "int", minimum: 1 },
              precio_unitario: { bsonType: ["double", "decimal", "int"], minimum: 0 },
              subtotal: { bsonType: ["double", "decimal", "int"], minimum: 0 }
            }
          }
        },
        total: {
          bsonType: ["double", "decimal", "int"],
          minimum: 0,
          description: "Importe total consolidado del pedido"
        }
      }
    }
  }
});

// 4. Creación de índices estratégicos para optimización de consultas
db.pedidos.createIndex({ pedido_id: 1 }, { unique: true, name: "idx_pedido_id_unique" });
db.pedidos.createIndex({ estado: 1 }, { name: "idx_estado" });
db.pedidos.createIndex({ "lineas.producto_id": 1 }, { name: "idx_multikey_lineas_producto" });
db.pedidos.createIndex({ total: 1 }, { name: "idx_total" });
db.pedidos.createIndex({ "cliente.cliente_id": 1 }, { name: "idx_cliente_id" });

// 5. Carga de datos mediante insertMany() con subconjunto de pedidos de Food Store
//    Se preservan identificadores de origen (pedido_id, cliente_id, producto_id)
//    y se congela el snapshot histórico de precios unitarios y subtotales.
const resultadoMigracion = db.pedidos.insertMany([
  {
    pedido_id: NumberInt(1),
    fecha: new Date("2026-06-05T20:30:00Z"),
    estado: "CONFIRMADO",
    forma_pago: "EFECTIVO",
    cliente: {
      cliente_id: NumberInt(2),
      nombre: "Juan",
      apellido: "Pérez",
      email: "juan@x.com",
      telefono: "2611234567"
    },
    lineas: [
      {
        producto_id: NumberInt(1),
        nombre: "Muzzarella",
        categoria: "Pizzas",
        cantidad: NumberInt(2),
        precio_unitario: 3200.00,
        subtotal: 6400.00
      },
      {
        producto_id: NumberInt(7),
        nombre: "Coca-Cola 500ml",
        categoria: "Bebidas",
        cantidad: NumberInt(3),
        precio_unitario: 900.00,
        subtotal: 2700.00
      }
    ],
    total: 9100.00
  },
  {
    pedido_id: NumberInt(2),
    fecha: new Date("2026-06-12T21:15:00Z"),
    estado: "TERMINADO",
    forma_pago: "TARJETA",
    cliente: {
      cliente_id: NumberInt(3),
      nombre: "María",
      apellido: "López",
      email: "maria@x.com",
      telefono: "2612345678"
    },
    lineas: [
      {
        producto_id: NumberInt(2),
        nombre: "Fugazzeta",
        categoria: "Pizzas",
        cantidad: NumberInt(1),
        precio_unitario: 3500.00,
        subtotal: 3500.00
      },
      {
        producto_id: NumberInt(4),
        nombre: "Carne",
        categoria: "Empanadas",
        cantidad: NumberInt(5),
        precio_unitario: 350.00,
        subtotal: 1750.00
      }
    ],
    total: 5250.00
  },
  {
    pedido_id: NumberInt(3),
    fecha: new Date("2026-06-20T22:00:00Z"),
    estado: "TERMINADO",
    forma_pago: "TRANSFERENCIA",
    cliente: {
      cliente_id: NumberInt(2),
      nombre: "Juan",
      apellido: "Pérez",
      email: "juan@x.com",
      telefono: "2611234567"
    },
    lineas: [
      {
        producto_id: NumberInt(3),
        nombre: "Napolitana",
        categoria: "Pizzas",
        cantidad: NumberInt(1),
        precio_unitario: 3800.00,
        subtotal: 3800.00
      }
    ],
    total: 3800.00
  },
  {
    pedido_id: NumberInt(4),
    fecha: new Date("2026-07-02T21:45:00Z"),
    estado: "TERMINADO",
    forma_pago: "EFECTIVO",
    cliente: {
      cliente_id: NumberInt(4),
      nombre: "Carlos",
      apellido: "Díaz",
      email: "carlos@x.com",
      telefono: "2613456789"
    },
    lineas: [
      {
        producto_id: NumberInt(1),
        nombre: "Muzzarella",
        categoria: "Pizzas",
        cantidad: NumberInt(3),
        precio_unitario: 3200.00,
        subtotal: 9600.00
      },
      {
        producto_id: NumberInt(9),
        nombre: "Cerveza artesanal",
        categoria: "Bebidas",
        cantidad: NumberInt(2),
        precio_unitario: 1500.00,
        subtotal: 3000.00
      }
    ],
    total: 12600.00
  },
  {
    pedido_id: NumberInt(5),
    fecha: new Date("2026-07-10T20:10:00Z"),
    estado: "CANCELADO",
    forma_pago: "TARJETA",
    cliente: {
      cliente_id: NumberInt(5),
      nombre: "Lucía",
      apellido: "Fernández",
      email: "lucia@x.com",
      telefono: "2614567890"
    },
    lineas: [
      {
        producto_id: NumberInt(2),
        nombre: "Fugazzeta",
        categoria: "Pizzas",
        cantidad: NumberInt(2),
        precio_unitario: 3500.00,
        subtotal: 7000.00
      }
    ],
    total: 7000.00
  },
  {
    pedido_id: NumberInt(6),
    fecha: new Date("2026-07-18T22:30:00Z"),
    estado: "TERMINADO",
    forma_pago: "EFECTIVO",
    cliente: {
      cliente_id: NumberInt(3),
      nombre: "María",
      apellido: "López",
      email: "maria@x.com",
      telefono: "2612345678"
    },
    lineas: [
      {
        producto_id: NumberInt(5),
        nombre: "Jamón y queso",
        categoria: "Empanadas",
        cantidad: NumberInt(10),
        precio_unitario: 350.00,
        subtotal: 3500.00
      },
      {
        producto_id: NumberInt(8),
        nombre: "Agua mineral",
        categoria: "Bebidas",
        cantidad: NumberInt(4),
        precio_unitario: 700.00,
        subtotal: 2800.00
      }
    ],
    total: 6300.00
  },
  {
    pedido_id: NumberInt(7),
    fecha: new Date("2026-07-25T21:00:00Z"),
    estado: "TERMINADO",
    forma_pago: "TARJETA",
    cliente: {
      cliente_id: NumberInt(2),
      nombre: "Juan",
      apellido: "Pérez",
      email: "juan@x.com",
      telefono: "2611234567"
    },
    lineas: [
      {
        producto_id: NumberInt(1),
        nombre: "Muzzarella",
        categoria: "Pizzas",
        cantidad: NumberInt(1),
        precio_unitario: 3200.00,
        subtotal: 3200.00
      },
      {
        producto_id: NumberInt(3),
        nombre: "Napolitana",
        categoria: "Pizzas",
        cantidad: NumberInt(1),
        precio_unitario: 3800.00,
        subtotal: 3800.00
      },
      {
        producto_id: NumberInt(10),
        nombre: "Flan casero",
        categoria: "Postres",
        cantidad: NumberInt(2),
        precio_unitario: 1200.00,
        subtotal: 2400.00
      }
    ],
    total: 9400.00
  },
  {
    pedido_id: NumberInt(8),
    fecha: new Date("2026-08-03T20:50:00Z"),
    estado: "CONFIRMADO",
    forma_pago: "EFECTIVO",
    cliente: {
      cliente_id: NumberInt(4),
      nombre: "Carlos",
      apellido: "Díaz",
      email: "carlos@x.com",
      telefono: "2613456789"
    },
    lineas: [
      {
        producto_id: NumberInt(6),
        nombre: "Humita",
        categoria: "Empanadas",
        cantidad: NumberInt(8),
        precio_unitario: 350.00,
        subtotal: 2800.00
      }
    ],
    total: 2800.00
  },
  {
    pedido_id: NumberInt(9),
    fecha: new Date("2026-08-11T21:20:00Z"),
    estado: "TERMINADO",
    forma_pago: "TRANSFERENCIA",
    cliente: {
      cliente_id: NumberInt(5),
      nombre: "Lucía",
      apellido: "Fernández",
      email: "lucia@x.com",
      telefono: "2614567890"
    },
    lineas: [
      {
        producto_id: NumberInt(2),
        nombre: "Fugazzeta",
        categoria: "Pizzas",
        cantidad: NumberInt(4),
        precio_unitario: 3500.00,
        subtotal: 14000.00
      },
      {
        producto_id: NumberInt(9),
        nombre: "Cerveza artesanal",
        categoria: "Bebidas",
        cantidad: NumberInt(1),
        precio_unitario: 1500.00,
        subtotal: 1500.00
      }
    ],
    total: 15500.00
  },
  {
    pedido_id: NumberInt(10),
    fecha: new Date("2026-08-19T22:10:00Z"),
    estado: "TERMINADO",
    forma_pago: "TARJETA",
    cliente: {
      cliente_id: NumberInt(3),
      nombre: "María",
      apellido: "López",
      email: "maria@x.com",
      telefono: "2612345678"
    },
    lineas: [
      {
        producto_id: NumberInt(1),
        nombre: "Muzzarella",
        categoria: "Pizzas",
        cantidad: NumberInt(5),
        precio_unitario: 3200.00,
        subtotal: 16000.00
      },
      {
        producto_id: NumberInt(7),
        nombre: "Coca-Cola 500ml",
        categoria: "Bebidas",
        cantidad: NumberInt(5),
        precio_unitario: 900.00,
        subtotal: 4500.00
      },
      {
        producto_id: NumberInt(10),
        nombre: "Flan casero",
        categoria: "Postres",
        cantidad: NumberInt(3),
        precio_unitario: 1200.00,
        subtotal: 3600.00
      }
    ],
    total: 24100.00
  }
]);

print(`[OK] Migración completada con éxito. Documentos insertados: ${resultadoMigracion.insertedCount}`);
