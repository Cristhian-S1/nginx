#!/usr/bin/env bash
# demo.sh — Script de demostración para presentación del taller
# Uso: sudo bash demo.sh [localhost|146.83.102.20]

TARGET="${1:-http://localhost}/validar"
SEP="══════════════════════════════════════════"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

query() {
  local result
  result=$(curl -s --max-time 5 "$TARGET" 2>/dev/null)
  if [ -z "$result" ]; then
    echo -e "  ${RED}[ERROR]${NC} Sin respuesta del servidor"
    return
  fi
  python3 -c "
import sys, json
d = json.loads('$result'.replace(\"'\", '\"'))
port   = d.get('port', '?')
status = d.get('status', '?')
ts     = d.get('processed_at', '')[-8:]
color  = '\033[0;32m' if status == 'aprobada' else '\033[0;31m'
nc     = '\033[0m'
print(f'  [:{port}]  {color}{status:12}{nc}  {ts}')
" 2>/dev/null || echo "  [ERROR] No se pudo parsear la respuesta"
}

echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║   VALIDADOR DE TRANSACCIONES — DEMO      ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════╝${NC}"
echo -e "  Target: ${YELLOW}$TARGET${NC}"
echo ""

# ── 1. ESTADO INICIAL ──
echo -e "${BOLD}[1/4] Estado inicial — todas las réplicas activas${NC}"
echo $SEP
for p in 3001 3002 3003; do
  STATUS=$(systemctl is-active "validador-tx@$p" 2>/dev/null || echo "unknown")
  COLOR=$GREEN; [ "$STATUS" != "active" ] && COLOR=$RED
  printf "  validador-tx@%-6s  ${COLOR}%s${NC}\n" "$p" "$STATUS"
done
echo ""
echo -e "  ${CYAN}Peticiones (Round-Robin):${NC}"
for i in {1..6}; do query; sleep 0.1; done
echo ""
read -p "  Presiona ENTER para la siguiente prueba..."

# ── 2. MATAR RÉPLICA 3002 ──
echo ""
echo -e "${BOLD}[2/4] Tolerancia a fallos — matando réplica :3002${NC}"
echo $SEP
echo -e "  ${YELLOW}→ sudo systemctl stop validador-tx@3002${NC}"
sudo systemctl stop validador-tx@3002
sleep 1
echo -e "  ${RED}  Réplica :3002 CAÍDA${NC}"
echo ""
echo -e "  ${CYAN}El sistema debe seguir respondiendo:${NC}"
for i in {1..6}; do query; sleep 0.1; done
echo ""
read -p "  Presiona ENTER para la siguiente prueba..."

# ── 3. MATAR RÉPLICA 3001 TAMBIÉN ──
echo ""
echo -e "${BOLD}[3/4] Prueba extrema — solo queda réplica :3003${NC}"
echo $SEP
echo -e "  ${YELLOW}→ sudo systemctl stop validador-tx@3001${NC}"
sudo systemctl stop validador-tx@3001
sleep 1
echo -e "  ${RED}  Réplicas :3001 y :3002 CAÍDAS — solo :3003 activa${NC}"
echo ""
echo -e "  ${CYAN}El sistema AÚN responde con la réplica restante:${NC}"
for i in {1..4}; do query; sleep 0.1; done
echo ""
read -p "  Presiona ENTER para restaurar..."

# ── 4. RESTAURAR TODO ──
echo ""
echo -e "${BOLD}[4/4] Restauración — levantando réplicas caídas${NC}"
echo $SEP
echo -e "  ${YELLOW}→ sudo systemctl start validador-tx@3001${NC}"
sudo systemctl start validador-tx@3001
echo -e "  ${YELLOW}→ sudo systemctl start validador-tx@3002${NC}"
sudo systemctl start validador-tx@3002
sleep 2
echo ""
echo -e "  ${GREEN}Sistema restaurado — Round-Robin completo:${NC}"
for i in {1..6}; do query; sleep 0.1; done

echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║  ✓ DEMO COMPLETADA — Sistema resiliente  ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
