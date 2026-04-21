# Simulacro de Despliegue y Presentación
## Validador de Transacciones — Taller Arquitectura N-Niveles

---

## Resumen de la arquitectura (lo que evalúa el profe)

```
Internet / Navegador
        │
        ▼ :80
  ┌─────────────┐
  │    NGINX    │  ← Puerta de enlace única (Load Balancer)
  │  Round-Robin│    Sirve frontend + rutea /validar
  └──┬────┬────┘
     │    │    │
     ▼    ▼    ▼
  :3001 :3002 :3003  ← Capa de Lógica (3 réplicas Go/Gin)
```

**N-Niveles presentes:**
- Nivel 1 — Cliente (navegador)
- Nivel 2 — Balanceador de carga (NGINX :80)
- Nivel 3 — Capa de lógica (réplicas Go :3001–3003)

---

## Parte A — Probar en Arch Linux (tu máquina)

### Estructura de archivos esperada

```
/opt/validador-tx/
├── validador-tx          ← binario compilado
└── static/
    └── index.html        ← frontend
```

### Copiar el frontend al lugar correcto

```bash
sudo mkdir -p /opt/validador-tx/static
sudo cp index.html /opt/validador-tx/static/
sudo chown -R http:http /opt/validador-tx
```

### Compilar con el nuevo main.go

```bash
cd ~/validador-tx
go mod tidy
go build -o validador-tx .
sudo cp validador-tx /opt/validador-tx/
sudo chown http:http /opt/validador-tx/validador-tx
```

### Reiniciar las 3 réplicas

```bash
sudo systemctl restart validador-tx@3001
sudo systemctl restart validador-tx@3002
sudo systemctl restart validador-tx@3003
```

### Actualizar config NGINX y recargar

```bash
sudo cp validador-tx.nginx.conf /etc/nginx/sites-enabled/validador-tx.conf
sudo nginx -t && sudo systemctl reload nginx
```

### Verificar todo

```bash
# Réplicas activas
for p in 3001 3002 3003; do
  echo -n ":$p → "; curl -s http://localhost:$p/health | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print('OK -', d['port'])"
done

# Frontend
curl -s http://localhost | grep -o '<title>.*</title>'

# Round-Robin por NGINX
for i in {1..6}; do
  curl -s http://localhost/validar | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d['status'],'→ réplica',d['port'])"
done
```

### Abrir frontend en el navegador

```
http://localhost
```

---

## Parte B — Despliegue en la VM del taller

```
Hostname : Ubuntu-vm-01
IP       : 146.83.102.20
OS       : Ubuntu Server
```

### B.1 — Conectarse a la VM

```bash
ssh usuario@146.83.102.20
# (usa el usuario y contraseña que te asignó el departamento)
```

### B.2 — Instalar dependencias (Ubuntu)

```bash
sudo apt update
sudo apt install -y golang nginx
```

### B.3 — Subir archivos desde tu Arch Linux

Desde tu máquina local, en la carpeta del proyecto:

```bash
# Crear directorio en la VM
ssh usuario@146.83.102.20 "mkdir -p ~/validador-tx"

# Copiar todos los archivos
scp main.go go.mod validador-tx.nginx.conf validador-tx@.service \
    usuario@146.83.102.20:~/validador-tx/

# Copiar frontend
scp index.html usuario@146.83.102.20:~/validador-tx/
```

### B.4 — Compilar en la VM

```bash
# (en la VM)
cd ~/validador-tx
go mod tidy
go build -o validador-tx .
```

### B.5 — Instalar binario y frontend

```bash
sudo mkdir -p /opt/validador-tx/static
sudo cp validador-tx /opt/validador-tx/
sudo chmod +x /opt/validador-tx/validador-tx
sudo cp index.html /opt/validador-tx/static/
sudo chown -R www-data:www-data /opt/validador-tx
```

### B.6 — Instalar servicio systemd (Ubuntu usa www-data)

El archivo `validador-tx@.service` ya viene con `User=www-data`, correcto para Ubuntu.

```bash
sudo cp validador-tx@.service /etc/systemd/system/
sudo systemctl daemon-reload

sudo systemctl enable --now validador-tx@3001
sudo systemctl enable --now validador-tx@3002
sudo systemctl enable --now validador-tx@3003
```

### B.7 — Configurar NGINX en Ubuntu

```bash
sudo cp validador-tx.nginx.conf /etc/nginx/sites-available/validador-tx
sudo ln -s /etc/nginx/sites-available/validador-tx \
           /etc/nginx/sites-enabled/validador-tx

# Deshabilitar el sitio por defecto
sudo rm -f /etc/nginx/sites-enabled/default

sudo nginx -t && sudo systemctl reload nginx
```

### B.8 — Verificar desde la VM

```bash
for p in 3001 3002 3003; do
  echo -n ":$p → "; curl -s http://localhost:$p/health
done
echo ""
for i in {1..6}; do
  curl -s http://localhost/validar | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d['status'],'→',d['port'])"
done
```

### B.9 — Verificar desde tu navegador (Arch)

Abre en tu navegador:

```
http://146.83.102.20
```

Debes ver el marketplace NovaPay y poder agregar productos al carrito.

### B.10 — Cambiar la URL de la API en el frontend

En `index.html`, línea con `const API_URL`, cambiar:

```js
// Para la VM del taller:
const API_URL = 'http://146.83.102.20/validar';
```

Volver a copiar el index.html actualizado a la VM y recargar NGINX.

---

## Parte C — Simulacro completo de la presentación

Este es el flujo exacto que el docente evaluará.

### C.1 — Demostrar Round-Robin funcionando

Ejecuta esto desde la VM o desde tu Arch:

```bash
echo "=== DEMOSTRANDO ROUND-ROBIN ==="
for i in {1..9}; do
  RESULT=$(curl -s http://146.83.102.20/validar)
  PORT=$(echo $RESULT | python3 -c "import sys,json; print(json.load(sys.stdin)['port'])")
  STATUS=$(echo $RESULT | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])")
  echo "Req $i → réplica :$PORT — $STATUS"
done
```

Salida esperada (patrón 3001→3002→3003 rotando):
```
Req 1 → réplica :3001 — aprobada
Req 2 → réplica :3002 — aprobada
Req 3 → réplica :3003 — aprobada
Req 4 → réplica :3001 — rechazada
Req 5 → réplica :3002 — aprobada
Req 6 → réplica :3003 — aprobada
...
```

### C.2 — Demostrar tolerancia a fallos (el profe "mata" un proceso)

**Paso 1 — Verificar estado inicial (todo activo):**

```bash
echo "=== ESTADO INICIAL ==="
for p in 3001 3002 3003; do
  STATUS=$(systemctl is-active validador-tx@$p)
  echo "validador-tx@$p: $STATUS"
done
```

**Paso 2 — Matar una réplica (simula lo que hará el profe):**

```bash
# Opción A: parar el servicio systemd
sudo systemctl stop validador-tx@3002

# Opción B: matar el proceso directamente (más dramático para la demo)
sudo kill $(pgrep -f "validador-tx" | head -2 | tail -1)
```

**Paso 3 — Verificar que el sistema sigue respondiendo:**

```bash
echo "=== SISTEMA CON RÉPLICA 3002 CAÍDA ==="
for i in {1..6}; do
  RESULT=$(curl -s http://146.83.102.20/validar)
  PORT=$(echo $RESULT | python3 -c "import sys,json; print(json.load(sys.stdin)['port'])")
  echo "Req $i → réplica :$PORT  (3002 está CAÍDA)"
done
```

Salida esperada — NGINX redistribuye solo entre 3001 y 3003:
```
Req 1 → réplica :3001  (3002 está CAÍDA)
Req 2 → réplica :3003  (3002 está CAÍDA)
Req 3 → réplica :3001  (3002 está CAÍDA)
Req 4 → réplica :3003  (3002 está CAÍDA)
...
```

**Paso 4 — Restaurar la réplica caída:**

```bash
sudo systemctl start validador-tx@3002
sleep 2

echo "=== SISTEMA RESTAURADO ==="
for i in {1..6}; do
  RESULT=$(curl -s http://146.83.102.20/validar)
  PORT=$(echo $RESULT | python3 -c "import sys,json; print(json.load(sys.stdin)['port'])")
  echo "Req $i → réplica :$PORT"
done
```

### C.3 — Matar dos réplicas (prueba extrema)

```bash
sudo systemctl stop validador-tx@3001
sudo systemctl stop validador-tx@3002

echo "=== SOLO RÉPLICA 3003 ACTIVA ==="
for i in {1..4}; do
  curl -s http://146.83.102.20/validar | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print('OK →',d['port'])"
done

# Restaurar
sudo systemctl start validador-tx@3001
sudo systemctl start validador-tx@3002
```

### C.4 — Script de demo completo (para presentar en 2 minutos)

Guarda este script como `demo.sh` y ejecútalo durante la presentación:

```bash
#!/usr/bin/env bash
TARGET="http://146.83.102.20/validar"   # cambia a localhost si es en Arch
SEP="─────────────────────────────────"

query() {
  curl -s "$TARGET" 2>/dev/null | python3 -c \
    "import sys,json
d=json.load(sys.stdin)
print(f\"  [{d['port']}] {d['status']:10} {d['processed_at'][-8:]}\")" \
  || echo "  [ERROR] sin respuesta"
}

echo ""
echo "1) ROUND-ROBIN — todas las réplicas activas"
echo $SEP
for i in {1..6}; do query; done

echo ""
echo "2) MATANDO réplica :3002..."
sudo systemctl stop validador-tx@3002
sleep 1
echo "   → systemctl stop validador-tx@3002"
echo $SEP
for i in {1..6}; do query; done

echo ""
echo "3) RESTAURANDO réplica :3002..."
sudo systemctl start validador-tx@3002
sleep 2
echo "   → systemctl start validador-tx@3002"
echo $SEP
for i in {1..6}; do query; done

echo ""
echo "✓ Demo completada. Sistema resiliente y operativo."
```

Ejecutar:

```bash
chmod +x demo.sh
sudo bash demo.sh
```

---

## Parte D — Comandos rápidos de referencia

### Estado del sistema

```bash
# Ver todas las réplicas de una vez
systemctl status validador-tx@{3001,3002,3003}

# Resumen compacto
for p in 3001 3002 3003; do
  printf "%-30s %s\n" "validador-tx@$p" "$(systemctl is-active validador-tx@$p)"
done

# Ver puertos en escucha
ss -tlnp | grep -E ':80|:300[123]'
```

### Control de réplicas

```bash
# Parar una réplica específica
sudo systemctl stop validador-tx@3002

# Iniciar una réplica específica
sudo systemctl start validador-tx@3002

# Reiniciar todas
sudo systemctl restart validador-tx@{3001,3002,3003}

# Logs de una réplica en tiempo real
sudo journalctl -fu validador-tx@3001

# Logs de las 3 a la vez
sudo journalctl -fu validador-tx@3001 & \
sudo journalctl -fu validador-tx@3002 & \
sudo journalctl -fu validador-tx@3003
```

### NGINX

```bash
sudo nginx -t                    # verificar configuración
sudo systemctl reload nginx      # recargar sin cortar conexiones
sudo systemctl restart nginx     # reinicio completo
sudo nginx -T | grep upstream    # ver upstream activo
tail -f /var/log/nginx/error.log # logs de error en tiempo real
```

### Prueba de carga rápida

```bash
# 50 requests seguidos, ver distribución
for i in {1..50}; do
  curl -s http://localhost/validar | python3 -c \
  "import sys,json; print(json.load(sys.stdin)['port'])"
done | sort | uniq -c | sort -rn
```

Resultado esperado (~equitativo):
```
  17 3001
  17 3002
  16 3003
```

---

## Parte E — Checklist de evaluación

Marca cada ítem antes de la presentación:

```
[ ] Las 3 réplicas responden en :3001, :3002, :3003
[ ] NGINX escucha en :80 y distribuye en Round-Robin
[ ] El frontend carga en http://146.83.102.20
[ ] El botón "Validar y pagar" llama GET /validar
[ ] La respuesta JSON incluye el campo "port"
[ ] Al matar :3002 el sistema sigue respondiendo con :3001 y :3003
[ ] Al restaurar :3002 vuelve a aparecer en la rotación
[ ] systemctl enable garantiza que las réplicas sobreviven un reboot
[ ] El JSON muestra 80% aprobadas / 20% rechazadas (aproximado)
[ ] NGINX es la única puerta de entrada (no se accede directo a :3001)
```
