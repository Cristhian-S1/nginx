# Validador de Transacciones

Servicio crítico de validación para e-commerce. 3 réplicas Golang/Gin balanceadas con NGINX Round-Robin.

## Requisitos previos

- Go 1.21+
- NGINX instalado (`sudo pacman go nginx`)
- systemd (incluido en Ubuntu/Debian/Arch)

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
