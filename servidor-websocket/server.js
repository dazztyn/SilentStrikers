const WebSocket = require('ws');
const wss = new WebSocket.Server({ port: 8080 });

const clients = new Set();

wss.on('connection', ws => {
  console.log('Nuevo cliente conectado');
  clients.add(ws);

  ws.on('message', message => {
    console.log('Mensaje recibido:', message.toString());

    // Reenviar el mensaje a todos los demás clientes
    for (const client of clients) {
      if (client !== ws && client.readyState === WebSocket.OPEN) {
        client.send(message.toString());
      }
    }
  });

  ws.on('close', () => {
    console.log('Cliente desconectado');
    clients.delete(ws);
  });
});

console.log("Servidor WebSocket listo en ws://localhost:8080");
