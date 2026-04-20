// app.js - Validador de Transacciones
const express = require('express');
const app = express();

const PORT = process.env.PORT || 3001;

app.get('/validar', (req, res) => {
  const aprobado = Math.random() < 0.8;
  const transactionId = `TXN-${Date.now()}-${Math.floor(Math.random() * 9999)}`;

  res.json({
    transactionId,
    status: aprobado ? 'APROBADA' : 'RECHAZADA',
    mensaje: aprobado
      ? 'Transacción aprobada exitosamente.'
      : 'Transacción rechazada. Fondos insuficientes o error de validación.',
    codigo: aprobado ? 200 : 402,
    replica_puerto: PORT,
    timestamp: new Date().toISOString(),
  });
});

app.listen(PORT, () => {
  console.log(`Validador de transacciones corriendo en puerto ${PORT}`);
});
