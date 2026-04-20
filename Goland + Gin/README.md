# Validador de Transacciones

Servicio crítico de validación para e-commerce. 3 réplicas Golang/Gin balanceadas con NGINX Round-Robin.

## Estructura de archivos

```
validador-tx/
├── main.go                   # Aplicación Golang con Gin
├── go.mod                    # Módulo y dependencias Go
├── validador-tx@.service     # Unit file systemd (template para 3 réplicas)
├── validador-tx.nginx.conf   # Configuración NGINX (upstream + server block)
├── deploy.sh                 # Script de despliegue automatizado
└── README.md                 # Este archivo
```

## Requisitos previos

- Go 1.21+
- NGINX instalado (`sudo apt install nginx`)
- systemd (incluido en Ubuntu/Debian/Arch)

## Despliegue rápido (automatizado)

```bash
sudo bash deploy.sh
```

## Despliegue manual paso a paso

### 1. Compilar

```bash
go mod tidy
go build -o validador-tx .
```

### 2. Instalar binario

```bash
sudo mkdir -p /opt/validador-tx
sudo cp validador-tx /opt/validador-tx/
sudo chown -R www-data:www-data /opt/validador-tx
```

### 3. Configurar systemd

```bash
sudo cp validador-tx@.service /etc/systemd/system/
sudo systemctl daemon-reload

# Habilitar e iniciar las 3 réplicas
sudo systemctl enable --now validador-tx@3001
sudo systemctl enable --now validador-tx@3002
sudo systemctl enable --now validador-tx@3003
```

### 4. Configurar NGINX

```bash
sudo cp validador-tx.nginx.conf /etc/nginx/sites-available/validador-tx
sudo ln -s /etc/nginx/sites-available/validador-tx /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

## Verificación

```bash
# Estado de las réplicas
sudo systemctl status validador-tx@3001
sudo systemctl status validador-tx@3002
sudo systemctl status validador-tx@3003

# Logs en tiempo real
sudo journalctl -fu validador-tx@3001

# Probar balanceo Round-Robin (el campo "port" debe rotar entre 3001, 3002, 3003)
for i in {1..6}; do curl -s http://localhost/validar | python3 -m json.tool; done
```

## Endpoint

`GET /validar`

**Respuesta aprobada (200):**
```json
{
  "status": "aprobada",
  "message": "Transacción aprobada correctamente.",
  "port": "3001",
  "processed_at": "2025-04-20T14:32:10Z"
}
```

**Respuesta rechazada (422):**
```json
{
  "status": "rechazada",
  "message": "Transacción rechazada por política de riesgo.",
  "port": "3002",
  "processed_at": "2025-04-20T14:32:11Z"
}
```

## Algoritmo de balanceo

**Round-Robin** (default NGINX). Elegido porque las validaciones son stateless y de carga uniforme, por lo que la distribución secuencial es óptima sin overhead de monitoreo.
