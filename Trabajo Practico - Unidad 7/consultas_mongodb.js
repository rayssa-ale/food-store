/**
 * =============================================================================
 * SCRIPT: consultas_mongodb.js
 * MATERIA: Bases de Datos II — Tecnicatura Universitaria en Programación (UTN FRM)
 * UNIDAD 7: NoSQL y nuevas formas de almacenamiento | Food Store
 * =============================================================================
 * 
 * OBJETIVO:
 * Ejecutar las 4 consultas documentales solicitadas en la Consigna 4 sobre la
 * colección 'pedidos' en MongoDB, aprovechando proyecciones, filtros por campo
 * escalar, búsqueda sobre arreglos embebidos (multikey) y filtros por rango numérico.
 * 
 * EJECUCIÓN:
 *   mongosh "mongodb://localhost:27017/foodstore" consultas_mongodb.js
 * =============================================================================
 */

db = db.getSiblingDB("foodstore");

print("\n===============================================================================");
print("CONSULTA 4.a: Mostrar todos los pedidos, incluyendo su identificador y estado");
print("===============================================================================");
// Proyección específica de identificadores (relacional original pedido_id y _id de Mongo),
// estado, fecha y total para visualización compacta.
const res4a = db.pedidos.find(
  {},
  { _id: 1, pedido_id: 1, estado: 1, total: 1 }
).sort({ pedido_id: 1 });

res4a.forEach(p => {
  print(`Pedido ID: ${p.pedido_id} | MongoDB _id: ${p._id} | Estado: ${p.estado} | Total: $${p.total}`);
});


print("\n===============================================================================");
print("CONSULTA 4.b: Filtrar pedidos por estado existente ('TERMINADO')");
print("===============================================================================");
// Filtro por valor exacto sobre campo escalar 'estado'.
// Estado seleccionado: 'TERMINADO' (equivalente a pedidos entregados/cerrados con éxito).
const res4b = db.pedidos.find(
  { estado: "TERMINADO" },
  { _id: 0, pedido_id: 1, fecha: 1, estado: 1, "cliente.nombre": 1, "cliente.apellido": 1, total: 1 }
).sort({ pedido_id: 1 });

let cont4b = 0;
res4b.forEach(p => {
  cont4b++;
  print(`[${cont4b}] Pedido ID: ${p.pedido_id} | Fecha: ${p.fecha.toISOString().split('T')[0]} | Cliente: ${p.cliente.nombre} ${p.cliente.apellido} | Total: $${p.total}`);
});
print(`--> Total pedidos en estado 'TERMINADO' recuperados en MongoDB: ${cont4b}`);


print("\n===============================================================================");
print("CONSULTA 4.c: Buscar pedidos con un producto determinado en el arreglo de líneas");
print("===============================================================================");
// Producto seleccionado: producto_id = 1 ("Muzzarella")
// MongoDB inspecciona de forma nativa los documentos internos del array 'lineas'
// sin necesidad de desarmar el array ($unwind) ni realizar JOINs externos.
const res4c = db.pedidos.find(
  { "lineas.producto_id": 1 },
  { _id: 0, pedido_id: 1, fecha: 1, estado: 1, total: 1, lineas: 1 }
).sort({ pedido_id: 1 });

let cont4c = 0;
res4c.forEach(p => {
  cont4c++;
  const lineaMuzza = p.lineas.find(l => l.producto_id === 1);
  print(`[${cont4c}] Pedido ID: ${p.pedido_id} | Estado: ${p.estado} | Total: $${p.total} | Detalle ítem: ${lineaMuzza.nombre} (Cant: ${lineaMuzza.cantidad}, Subtotal: $${lineaMuzza.subtotal})`);
});
print(`--> Total pedidos con Producto 1 ('Muzzarella') en MongoDB: ${cont4c}`);


print("\n===============================================================================");
print("CONSULTA 4.d: Buscar pedidos cuyo total sea superior a un importe ($gt: 8000.00)");
print("===============================================================================");
/**
 * JUSTIFICACIÓN TÉCNICA DEL UMBRAL ($8.000,00):
 * En la distribución de tickets del seed de Food Store, los pedidos oscilan entre
 * $2.800,00 y $24.100,00, con un valor medio de $9.880,00 y una mediana de $8.050,00.
 * Establecer el umbral en $8.000,00 permite discriminar con precisión analítica
 * los pedidos individuales o colaciones rápidas (empanadas o bebidas sueltas de ticket bajo)
 * de los pedidos de consumo grupal o familiar (múltiples pizzas y bebidas), que representan
 * el 50% de mayor facturación del negocio.
 */
const UMBRAL = 8000.00;
const res4d = db.pedidos.find(
  { total: { $gt: UMBRAL } },
  { _id: 0, pedido_id: 1, fecha: 1, estado: 1, total: 1, "cliente.nombre": 1, "cliente.apellido": 1 }
).sort({ total: -1 });

let cont4d = 0;
res4d.forEach(p => {
  cont4d++;
  print(`[${cont4d}] Pedido ID: ${p.pedido_id} | Total: $${p.total} | Cliente: ${p.cliente.nombre} ${p.cliente.apellido} | Estado: ${p.estado}`);
});
print(`--> Total pedidos con importe > $${UMBRAL} en MongoDB: ${cont4d}`);
print("===============================================================================\n");
