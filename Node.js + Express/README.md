# Validador de Transacciones — E-Commerce

Servicio crítico de validación de transacciones con 3 réplicas y balanceo de carga via NGINX.

---

## Estructura del proyecto

```
validador-transacciones/
├── app.js                            # Aplicación Express
├── ecosystem.config.js               # Configuración PM2 (3 réplicas)
├── package.json
├── validador-transacciones.nginx.conf  # Configuración NGINX
└── README.md
```

---

## Instalación

```bash
# 1. Instalar dependencias Node
npm install

# 2. Instalar PM2 globalmente (si no lo tienes)
npm install -g pm2
```

---

## Levantar las 3 réplicas con PM2

```bash
# Iniciar las 3 réplicas
pm2 start ecosystem.config.js

# Guardar configuración para sobrevivir reinicios
pm2 save

# Generar script de arranque automático del sistema
# (ejecuta el comando que te indique la salida)
pm2 startup
```

### Comandos útiles PM2

```bash
pm2 list                  # Ver estado de todas las réplicas
pm2 logs                  # Ver logs en tiempo real
pm2 restart all           # Reiniciar todas las réplicas
pm2 stop all              # Detener todas las réplicas
pm2 delete all            # Eliminar todas las réplicas de PM2
pm2 monit                 # Monitor interactivo (CPU, RAM)
```

---

## Configurar NGINX

```bash
# Copiar configuración
sudo cp validador-transacciones.nginx.conf /etc/nginx/sites-available/validador-transacciones

# Activar el sitio
sudo ln -s /etc/nginx/sites-available/validador-transacciones /etc/nginx/sites-enabled/

# Verificar sintaxis
sudo nginx -t

# Recargar NGINX
sudo systemctl reload nginx
```

---

## Prueba del sistema

```bash
# Prueba individual
curl http://localhost/validar

# Prueba de balanceo (6 peticiones — observa replica_puerto rotando)
for i in {1..6}; do
  curl -s http://localhost/validar | python3 -m json.tool
  echo "---"
done
```

### Respuesta de ejemplo (transacción aprobada)

```json
{
  "transactionId": "TXN-1718300000000-4821",
  "status": "APROBADA",
  "mensaje": "Transacción aprobada exitosamente.",
  "codigo": 200,
  "replica_puerto": 3002,
  "timestamp": "2024-06-13T14:00:00.000Z"
}
```

### Respuesta de ejemplo (transacción rechazada)

```json
{
  "transactionId": "TXN-1718300000001-1234",
  "status": "RECHAZADA",
  "mensaje": "Transacción rechazada. Fondos insuficientes o error de validación.",
  "codigo": 402,
  "replica_puerto": 3003,
  "timestamp": "2024-06-13T14:00:00.001Z"
}
```

---

## Arquitectura

```
Cliente
   │
   ▼
NGINX :80  (least_conn)
   │
   ├──▶ Réplica :3001 (PM2)
   ├──▶ Réplica :3002 (PM2)
   └──▶ Réplica :3003 (PM2)
```

**Algoritmo:** `least_conn` — envía cada petición a la réplica con menos conexiones activas,
ideal para validaciones con latencia variable (antifraude, verificación de saldo, etc.).
