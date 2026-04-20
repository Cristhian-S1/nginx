#!/usr/bin/env bash
# deploy.sh — Script de despliegue completo para Validador de Transacciones
# Ejecutar como root o con sudo

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/opt/validador-tx"
BINARY_NAME="validador-tx"
SERVICE_TEMPLATE="validador-tx@.service"
NGINX_CONF="validador-tx.nginx.conf"
NGINX_SITES_AVAILABLE="/etc/nginx/sites-available/validador-tx"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled/validador-tx"

echo "==> [1/6] Compilando binario Go..."
cd "$PROJECT_DIR"
go build -o "$BINARY_NAME" .

echo "==> [2/6] Instalando binario en $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
cp "$BINARY_NAME" "$INSTALL_DIR/"
chown -R www-data:www-data "$INSTALL_DIR"
chmod +x "$INSTALL_DIR/$BINARY_NAME"

echo "==> [3/6] Instalando unit file de systemd..."
cp "$SERVICE_TEMPLATE" /etc/systemd/system/
systemctl daemon-reload

echo "==> [4/6] Habilitando e iniciando las 3 réplicas..."
for PORT in 3001 3002 3003; do
    systemctl enable --now "validador-tx@${PORT}"
    echo "    Réplica :${PORT} iniciada."
done

echo "==> [5/6] Configurando NGINX..."
cp "$NGINX_CONF" "$NGINX_SITES_AVAILABLE"
ln -sf "$NGINX_SITES_AVAILABLE" "$NGINX_SITES_ENABLED"
nginx -t && systemctl reload nginx

echo "==> [6/6] Verificando despliegue..."
sleep 2
for PORT in 3001 3002 3003; do
    STATUS=$(systemctl is-active "validador-tx@${PORT}")
    echo "    validador-tx@${PORT}: $STATUS"
done

echo ""
echo "✓ Despliegue completado. Prueba con:"
echo "  for i in {1..6}; do curl -s http://localhost/validar | python3 -m json.tool; done"
