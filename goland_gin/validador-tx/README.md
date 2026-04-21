# Validador de Transacciones

Servicio crítico de validación para e-commerce. 3 réplicas Golang/Gin balanceadas con NGINX Round-Robin.

## Requisitos previos

- Go 1.21+
- NGINX instalado (`sudo pacman go nginx`)
- systemd (incluido en Ubuntu/Debian/Arch)

## Despliegue manual paso a paso

# Validador de Transacciones — Guía Completa de Despliegue

Marketplace e-commerce con validación de pagos distribuida. 3 réplicas Go/Gin balanceadas con NGINX Round-Robin, frontend estático servido por NGINX.

---

## Índice

1. [Arquitectura del sistema](#1-arquitectura-del-sistema)
2. [Estructura de archivos del proyecto](#2-estructura-de-archivos-del-proyecto)
3. [Arch Linux — Instalación completa](#3-arch-linux--instalación-completa)
4. [Debian/Ubuntu — Instalación completa](#4-debianubuntu--instalación-completa)
5. [Verificación del sistema](#5-verificación-del-sistema)
6. [Reversión completa — Arch Linux](#6-reversión-completa--arch-linux)
7. [Reversión completa — Debian/Ubuntu](#7-reversión-completa--debianubuntu)
8. [Diferencias clave entre distros](#8-diferencias-clave-entre-distros)
9. [Referencia rápida de comandos](#9-referencia-rápida-de-comandos)

---

## 1. Arquitectura del sistema

```
Navegador (cliente)
        │
        ▼  puerto 80
┌───────────────────────────────┐
│            NGINX              │
│  ┌─────────────────────────┐  │
│  │  root /opt/.../static   │  │  ← Sirve index.html (frontend)
│  │  location /validar      │  │  ← Proxy hacia réplicas Go
│  └─────────────────────────┘  │
└──────────┬─────┬──────┬───────┘
           │     │      │   Round-Robin: 3001→3002→3003→3001...
           ▼     ▼      ▼
        :3001  :3002  :3003      ← Réplicas Go/Gin (mismo binario, PORT distinto)
```

**Niveles de la arquitectura N-Tier:**
- **Nivel 1** — Cliente (navegador, cualquier red)
- **Nivel 2** — Balanceador de carga (NGINX :80) — única puerta de entrada
- **Nivel 3** — Capa de lógica de negocio (3 réplicas Go/Gin)

**Endpoints disponibles:**

| Ruta | Descripción |
|------|-------------|
| `GET /` | Frontend del marketplace |
| `GET /validar` | Validación de transacción (80% aprobada, 20% rechazada) |
| `GET /health` | Health check de la réplica que responde |

---

## 2. Estructura de archivos del proyecto

```
proyecto/
├── main.go                    # Aplicación Go con Gin (lógica + rutas)
├── go.mod                     # Módulo Go y declaración de dependencias
├── index.html                 # Frontend del marketplace (va en static/)
├── validador-tx@.service      # Unit file systemd (template para 3 réplicas)
├── validador-tx.nginx.conf    # Configuración NGINX completa
├── demo.sh                    # Script de demostración para presentación
└── SIMULACRO.md               # Guía de presentación paso a paso
```

**Rutas de instalación en el servidor:**

| Archivo | Destino |
|---------|---------|
| Binario compilado | `/opt/validador-tx/validador-tx` |
| Frontend | `/opt/validador-tx/static/index.html` |
| Unit systemd | `/etc/systemd/system/validador-tx@.service` |
| Config NGINX (Arch) | `/etc/nginx/sites-enabled/validador-tx.conf` |
| Config NGINX (Ubuntu) | `/etc/nginx/sites-available/validador-tx` |

---

## 3. Arch Linux — Instalación completa

### 3.1 Instalar dependencias

```bash
sudo pacman -S go nginx
```

Verifica:

```bash
go version
# go version go1.x.x linux/amd64

nginx -v
# nginx version: nginx/1.x.x
```

### 3.2 Compilar el proyecto

Crea una carpeta de trabajo, coloca `main.go` y `go.mod` ahí:

```bash
mkdir -p ~/validador-tx
cd ~/validador-tx
# Copia main.go y go.mod a esta carpeta
```

Descarga dependencias y compila:

```bash
go mod tidy        # lee go.mod, descarga Gin y sus dependencias, genera go.sum
go build -o validador-tx .   # genera el ejecutable ./validador-tx
```

Prueba rápida antes de instalar:

```bash
PORT=3001 ./validador-tx &   # ejecuta en segundo plano
sleep 1
curl -s http://localhost:3001/health   # debe responder JSON
curl -s http://localhost:3001/validar  # debe responder con status y port
kill %1   # detener la prueba
```

### 3.3 Instalar el binario y el frontend

```bash
# Crear estructura de directorios
sudo mkdir -p /opt/validador-tx/static

# Copiar el binario
sudo cp validador-tx /opt/validador-tx/
sudo chmod +x /opt/validador-tx/validador-tx

# Copiar el frontend
sudo cp index.html /opt/validador-tx/static/

# En Arch el usuario de NGINX es "http" (no www-data)
sudo chown -R http:http /opt/validador-tx
```

> **Por qué `http` y no `www-data`:** En Arch Linux, el paquete `nginx` crea un usuario del sistema llamado `http` que es el owner del proceso NGINX. En Debian/Ubuntu ese usuario se llama `www-data`. El unit file de systemd debe coincidir con el usuario real, de lo contrario el proceso no tendrá permiso de lectura sobre los archivos.

### 3.4 Instalar el servicio systemd

El archivo `validador-tx@.service` usa **template units** de systemd. El símbolo `@` en el nombre significa que es una plantilla: al instanciar con `validador-tx@3001`, systemd sustituye automáticamente `%i` → `3001` en todo el archivo (en el `Description` y en `Environment="PORT=%i"`). Un solo archivo `.service` controla las 3 réplicas.

Ajusta el usuario para Arch:

```bash
# El archivo viene con User=www-data, cámbialo a http
sed -i 's/User=www-data/User=http/' validador-tx@.service
```

Instala y levanta:

```bash
sudo cp validador-tx@.service /etc/systemd/system/
sudo systemctl daemon-reload   # notifica a systemd del nuevo archivo

sudo systemctl enable --now validador-tx@3001
sudo systemctl enable --now validador-tx@3002
sudo systemctl enable --now validador-tx@3003
```

> `--now` es la combinación de `enable` (persistencia al reboot) más `start` (inicio inmediato). Sin `enable`, el servicio muere al reiniciar la máquina. Sin `start`, queda habilitado pero no corre hasta el próximo boot.

Verifica:

```bash
sudo systemctl status validador-tx@3001
sudo systemctl status validador-tx@3002
sudo systemctl status validador-tx@3003
# Busca: Active: active (running)
```

### 3.5 Configurar NGINX en Arch Linux

Arch no incluye el sistema `sites-available/sites-enabled/` de Debian. Se crea manualmente:

```bash
sudo mkdir -p /etc/nginx/sites-enabled
sudo cp validador-tx.nginx.conf /etc/nginx/sites-enabled/validador-tx.conf
```

Agrega el `include` al final del bloque `http {}` en `/etc/nginx/nginx.conf`:

```bash
sudo sed -i '/^http {/,/^}/ { /^}/i\    include sites-enabled/*.conf;
}' /etc/nginx/nginx.conf
```

**Paso crítico específico de Arch:** El `nginx.conf` por defecto de Arch tiene un bloque `server { listen 80; }` embebido dentro de `http {}`. NGINX procesa los bloques `server` en orden de aparición, y ese bloque por defecto intercepta todo el tráfico del puerto 80 antes de que llegue tu configuración de `sites-enabled`. Debes comentarlo:

```bash
sudo nano /etc/nginx/nginx.conf
```

Busca y comenta todo el bloque `server { }` que está dentro de `http { }`. El archivo debe quedar así en su sección relevante:

```nginx
http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    # Bloque server por defecto COMENTADO.
    # Si no se comenta, intercepta el puerto 80 antes que sites-enabled.
    #server {
    #    listen       80;
    #    server_name  localhost;
    #    location / {
    #        root   /usr/share/nginx/html;
    #        index  index.html index.htm;
    #    }
    #    error_page   500 502 503 504  /50x.html;
    #    location = /50x.html {
    #        root   /usr/share/nginx/html;
    #    }
    #}

    include sites-enabled/*.conf;
}
```

Verifica y activa:

```bash
sudo nginx -t
# nginx: the configuration file ... syntax is ok
# nginx: configuration file ... test is successful

sudo systemctl enable --now nginx
sudo systemctl reload nginx
```

> El warning `could not build optimal types_hash` que aparece es inofensivo. Puede eliminarse agregando `types_hash_max_size 4096;` dentro del bloque `http {}`, pero no afecta el funcionamiento.

### 3.6 Verificar la instalación completa en Arch

```bash
# 1. Réplicas directas (sin NGINX)
for p in 3001 3002 3003; do
  echo -n "Réplica :$p → "
  curl -s http://localhost:$p/health | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print('OK · port', d['port'])"
done

# 2. Frontend por NGINX
curl -s http://localhost | grep -o '<title>.*</title>'
# debe mostrar: <title>NovaPay — Marketplace</title>

# 3. Round-Robin por NGINX
for i in {1..6}; do
  curl -s http://localhost/validar | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print(d['status'], '→ réplica', d['port'])"
done
```

Abre en el navegador: `http://localhost`

---

## 4. Debian/Ubuntu — Instalación completa

> Esta sección aplica a la VM asignada: **Ubuntu-vm-01 · IP 146.83.102.20**

### 4.1 Instalar dependencias

```bash
sudo apt update
sudo apt install -y golang nginx
```

Verifica:

```bash
go version
nginx -v
```

### 4.2 Compilar el proyecto

```bash
mkdir -p ~/validador-tx
cd ~/validador-tx
# Copia main.go y go.mod a esta carpeta (vía scp o editor)
go mod tidy
go build -o validador-tx .
```

Copiar archivos desde tu Arch Linux hacia la VM (ejecuta desde Arch):

```bash
# Crear directorio remoto
ssh usuario@146.83.102.20 "mkdir -p ~/validador-tx"

# Transferir todos los archivos
scp main.go go.mod index.html validador-tx.nginx.conf validador-tx@.service \
    usuario@146.83.102.20:~/validador-tx/
```

### 4.3 Instalar binario y frontend

En Ubuntu el usuario de NGINX es `www-data`. El `validador-tx@.service` viene configurado con `User=www-data` por defecto, así que no requiere modificación.

```bash
sudo mkdir -p /opt/validador-tx/static

sudo cp validador-tx /opt/validador-tx/
sudo chmod +x /opt/validador-tx/validador-tx

sudo cp index.html /opt/validador-tx/static/

sudo chown -R www-data:www-data /opt/validador-tx
```

### 4.4 Instalar el servicio systemd

No se necesita modificar el `User=` esta vez:

```bash
sudo cp validador-tx@.service /etc/systemd/system/
sudo systemctl daemon-reload

sudo systemctl enable --now validador-tx@3001
sudo systemctl enable --now validador-tx@3002
sudo systemctl enable --now validador-tx@3003
```

Verifica:

```bash
sudo systemctl status validador-tx@{3001,3002,3003}
```

### 4.5 Configurar NGINX en Debian/Ubuntu

Ubuntu incluye el sistema `sites-available` / `sites-enabled` de forma nativa. No hay que editar `nginx.conf` a mano.

```bash
# Instalar la configuración
sudo cp validador-tx.nginx.conf /etc/nginx/sites-available/validador-tx

# Activar con symlink
sudo ln -s /etc/nginx/sites-available/validador-tx \
           /etc/nginx/sites-enabled/validador-tx

# Deshabilitar el sitio por defecto que ocupa el puerto 80
sudo rm /etc/nginx/sites-enabled/default

# Verificar y recargar
sudo nginx -t
sudo systemctl reload nginx
```

> **Por qué se borra `default` y no se comenta:** En Ubuntu, el sitio por defecto es un archivo independiente en `sites-available/default`. Al eliminar solo el symlink en `sites-enabled/`, se desactiva sin tocar el archivo original. Si alguna vez necesitas restaurarlo: `sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default`.

### 4.6 Cambiar la URL de la API en el frontend

El frontend tiene la URL de la API hardcodeada. Para que funcione desde cualquier navegador que acceda a la VM, debe apuntar a la IP pública:

Edita `/opt/validador-tx/static/index.html` en la VM, busca la línea:

```js
const API_URL = 'http://localhost/validar';
```

Cámbiala por:

```js
const API_URL = 'http://146.83.102.20/validar';
```

O hazlo directamente desde Arch antes de subir el archivo:

```bash
# En tu Arch, antes del scp:
sed -i "s|http://localhost/validar|http://146.83.102.20/validar|" index.html
```

### 4.7 Verificar la instalación completa en Ubuntu

```bash
# En la VM
for p in 3001 3002 3003; do
  echo -n "Réplica :$p → "
  curl -s http://localhost:$p/health | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print('OK · port', d['port'])"
done

# Frontend
curl -s http://localhost | grep -o '<title>.*</title>'

# Round-Robin
for i in {1..6}; do
  curl -s http://localhost/validar | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print(d['status'], '→', d['port'])"
done
```

Desde tu navegador en Arch: `http://146.83.102.20`

---

## 5. Verificación del sistema

Estos comandos funcionan igual en ambas distros:

```bash
# Estado compacto de las 3 réplicas
for p in 3001 3002 3003; do
  printf "validador-tx@%-6s → %s\n" "$p" "$(systemctl is-active validador-tx@$p)"
done

# Puertos en escucha (deben aparecer 80, 3001, 3002, 3003)
ss -tlnp | grep -E ':80|:300[123]'

# Distribución del Round-Robin (30 requests)
echo "Distribución Round-Robin (30 requests):"
for i in {1..30}; do
  curl -s http://localhost/validar | python3 -c \
    "import sys,json; print(json.load(sys.stdin)['port'])"
done | sort | uniq -c | sort -rn
# Resultado esperado: ~10 por cada réplica

# Simular caída y recuperación
sudo systemctl stop validador-tx@3002
echo "Con :3002 caída (solo 3001 y 3003 deben aparecer):"
for i in {1..4}; do
  curl -s http://localhost/validar | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print(d['port'])"
done
sudo systemctl start validador-tx@3002
```

---

## 6. Reversión completa — Arch Linux

Los pasos están en orden inverso a la instalación.

### 6.1 Detener y deshabilitar las réplicas

```bash
sudo systemctl stop validador-tx@3001
sudo systemctl stop validador-tx@3002
sudo systemctl stop validador-tx@3003

sudo systemctl disable validador-tx@3001
sudo systemctl disable validador-tx@3002
sudo systemctl disable validador-tx@3003
```

Confirma que están detenidas:

```bash
for p in 3001 3002 3003; do
  echo "validador-tx@$p: $(systemctl is-active validador-tx@$p)"
done
# Debe mostrar "inactive" en las tres
```

### 6.2 Eliminar el unit file y limpiar systemd

```bash
# Eliminar el template unit
sudo rm /etc/systemd/system/validador-tx@.service

# Eliminar los symlinks de las instancias (creados por --enable)
sudo rm -f /etc/systemd/system/multi-user.target.wants/validador-tx@3001.service
sudo rm -f /etc/systemd/system/multi-user.target.wants/validador-tx@3002.service
sudo rm -f /etc/systemd/system/multi-user.target.wants/validador-tx@3003.service

# Notificar a systemd y limpiar unidades fallidas
sudo systemctl daemon-reload
sudo systemctl reset-failed
```

Verifica que systemd ya no conoce el servicio:

```bash
systemctl status validador-tx@3001
# Debe decir: Unit validador-tx@3001.service could not be found.
```

### 6.3 Eliminar el binario y el frontend

```bash
sudo rm -rf /opt/validador-tx
```

Confirma:

```bash
ls /opt/validador-tx 2>&1
# Debe decir: No such file or directory
```

### 6.4 Revertir la configuración de NGINX en Arch

Paso 1 — Elimina la configuración del servicio:

```bash
sudo rm /etc/nginx/sites-enabled/validador-tx.conf
```

Si la carpeta `sites-enabled` la creaste solo para este proyecto y está vacía, puedes eliminarla:

```bash
# Solo si está vacía:
sudo rmdir /etc/nginx/sites-enabled
```

Paso 2 — Elimina la línea `include sites-enabled/*.conf;` que agregó el `sed`:

```bash
sudo nano /etc/nginx/nginx.conf
```

Elimina esta línea al final del bloque `http {}`:

```nginx
    include sites-enabled/*.conf;   ← ELIMINA ESTA LÍNEA
```

Paso 3 — Descomenta el server block por defecto (quita todos los `#`):

```nginx
http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    server {
        listen       80;
        server_name  localhost;
        location / {
            root   /usr/share/nginx/html;
            index  index.html index.htm;
        }
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /usr/share/nginx/html;
        }
    }
}
```

Paso 4 — Verifica y recarga:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

Confirma que NGINX volvió a su estado original:

```bash
curl http://localhost
# Debe devolver el HTML de bienvenida de NGINX ("Welcome to nginx!")
```

### 6.5 Desinstalar paquetes (opcional)

Solo si no los usas para otra cosa:

```bash
sudo pacman -Rns nginx
sudo pacman -Rns go
```

`-Rns` elimina el paquete (`R`), sus dependencias que ya no son necesarias (`n`) y los archivos de configuración generados por el paquete (`s`). Nota: los archivos que tú creaste manualmente (como los que editaste en `/etc/nginx/`) no se eliminan con `-s`, esos deberás borrarlos tú si quieres limpieza total.

---

## 7. Reversión completa — Debian/Ubuntu

### 7.1 Detener y deshabilitar las réplicas

```bash
sudo systemctl stop validador-tx@3001
sudo systemctl stop validador-tx@3002
sudo systemctl stop validador-tx@3003

sudo systemctl disable validador-tx@3001
sudo systemctl disable validador-tx@3002
sudo systemctl disable validador-tx@3003
```

### 7.2 Eliminar el unit file y limpiar systemd

```bash
sudo rm /etc/systemd/system/validador-tx@.service
sudo systemctl daemon-reload
sudo systemctl reset-failed
```

### 7.3 Eliminar binario y frontend

```bash
sudo rm -rf /opt/validador-tx
```

### 7.4 Revertir la configuración de NGINX en Ubuntu

Paso 1 — Elimina el symlink activo y el archivo de configuración:

```bash
sudo rm /etc/nginx/sites-enabled/validador-tx
sudo rm /etc/nginx/sites-available/validador-tx
```

Paso 2 — Restaura el sitio por defecto:

```bash
sudo ln -s /etc/nginx/sites-available/default \
           /etc/nginx/sites-enabled/default
```

Paso 3 — Verifica y recarga:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

Confirma que NGINX volvió a su estado original:

```bash
curl http://localhost
# Debe devolver el HTML de bienvenida de NGINX
```

### 7.5 Desinstalar paquetes (opcional)

```bash
sudo apt remove nginx golang
sudo apt autoremove   # elimina dependencias huérfanas
sudo apt purge nginx  # elimina también archivos de configuración del paquete
```

---

## 8. Diferencias clave entre distros

| Aspecto | Arch Linux | Debian/Ubuntu |
|---------|-----------|---------------|
| Instalar Go | `pacman -S go` | `apt install golang` |
| Instalar NGINX | `pacman -S nginx` | `apt install nginx` |
| Usuario NGINX | `http` | `www-data` |
| Ajuste en `.service` | `sed -i 's/www-data/http/'` | Sin cambios |
| Sistema de sitios | Manual: crear `sites-enabled/` | Nativo: `sites-available/` + `sites-enabled/` |
| Activar configuración | Copiar archivo a `sites-enabled/` | `ln -s sites-available/X sites-enabled/X` |
| Conflicto puerto 80 | Comentar server block en `nginx.conf` | `rm /etc/nginx/sites-enabled/default` |
| Revertir NGINX | Descomentar server block + eliminar include | Restaurar symlink `default` |
| Desinstalar | `pacman -Rns paquete` | `apt remove + apt autoremove` |
| Logs | `journalctl -u servicio` | `journalctl -u servicio` |

---

## 9. Referencia rápida de comandos

### Control de réplicas

```bash
# Ver estado de las 3 de un vistazo
for p in 3001 3002 3003; do
  printf "%-30s %s\n" "validador-tx@$p" "$(systemctl is-active validador-tx@$p)"
done

# Parar una réplica (simular fallo)
sudo systemctl stop validador-tx@3002

# Iniciar una réplica (restaurar)
sudo systemctl start validador-tx@3002

# Reiniciar todas
sudo systemctl restart validador-tx@3001
sudo systemctl restart validador-tx@3002
sudo systemctl restart validador-tx@3003

# Ver logs en tiempo real de una réplica
sudo journalctl -fu validador-tx@3001

# Ver logs de las 3 simultáneamente
sudo journalctl -fu validador-tx@3001 &
sudo journalctl -fu validador-tx@3002 &
sudo journalctl -fu validador-tx@3003
```

### Control de NGINX

```bash
sudo nginx -t                      # verificar sintaxis
sudo systemctl reload nginx        # recargar sin cortar conexiones activas
sudo systemctl restart nginx       # reinicio completo
sudo systemctl status nginx        # ver estado
tail -f /var/log/nginx/error.log   # logs de error en tiempo real
```

### Pruebas de API

```bash
# Health check por réplica (directo, sin NGINX)
curl -s http://localhost:3001/health | python3 -m json.tool
curl -s http://localhost:3002/health | python3 -m json.tool
curl -s http://localhost:3003/health | python3 -m json.tool

# Verificar Round-Robin (el campo "port" debe rotar)
for i in {1..9}; do
  curl -s http://localhost/validar | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print(f\"Req $i → :{d['port']} — {d['status']}\")"
done

# Distribución estadística (50 requests)
for i in {1..50}; do
  curl -s http://localhost/validar | python3 -c \
    "import sys,json; print(json.load(sys.stdin)['port'])"
done | sort | uniq -c | sort -rn

# Verificar puertos en escucha
ss -tlnp | grep -E ':80|:300[123]'
```

### Demo de tolerancia a fallos

```bash
# 1. Matar réplica 3002
sudo systemctl stop validador-tx@3002

# 2. Confirmar que el sistema sigue respondiendo
for i in {1..4}; do
  curl -s http://localhost/validar | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print('OK →', d['port'])"
done

# 3. Restaurar
sudo systemctl start validador-tx@3002

# 4. Demo automatizada completa (con pauses)
sudo bash demo.sh
# o para la VM:
sudo bash demo.sh http://146.83.102.20
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
