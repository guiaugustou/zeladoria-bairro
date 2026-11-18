#!/usr/bin/env bash
# Teste de falha 1 - a API cai e se recupera.
#   Parte A: "kill -9" no processo da API  -> o próprio systemd religa (Restart=on-failure).
#   Parte B: "systemctl stop" (parada manual) -> o systemd NÃO religa; o monitor percebe e reinicia.
# Uso: sudo bash infra-os/testes-de-falha/01-parar-api.sh   (precisa do 01, 02 e 03 instalados)

DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR_SCRIPT/../scripts/lib.sh"
exigir_root
iniciar_script "$@"

API=zeladoria-api.service
MONITOR=zeladoria-monitor.service
URL_HEALTH="${URL_HEALTH:-http://127.0.0.1:8000/health}"
LOG_MONITOR="$LOG_DIR/monitor.log"

api_ok() { curl -fsS --max-time 2 "$URL_HEALTH" > /dev/null 2>&1; }

# Espera a API responder; mostra os segundos. Falha se passar do limite.
esperar_api() {   # esperar_api LIMITE_EM_SEGUNDOS
  local t=0
  while [ "$t" -lt "$1" ]; do
    if api_ok; then echo "$t"; return 0; fi
    sleep 1
    t=$((t + 1))
  done
  return 1
}

info "0/2 Verificações iniciais"
systemctl is-active --quiet "$API" || { erro "a API não está ativa: rode antes o 02-app.sh"; exit 1; }
systemctl is-active --quiet "$MONITOR" || { erro "o monitor não está ativo: rode antes o 03-monitor.sh"; exit 1; }
api_ok || { erro "a API não responde em $URL_HEALTH"; exit 1; }
info "estado inicial: API=$(systemctl is-active "$API") monitor=$(systemctl is-active "$MONITOR") health=$(curl -fsS "$URL_HEALTH")"

# ---------------------------------------------------------------
info "A) Matando o processo da API com kill -9 (queda brusca)"
auditar "TESTE DE FALHA kill -9 na API"
pid_antes="$(systemctl show -p MainPID --value "$API")"
info "PID da API antes: $pid_antes"
kill -9 "$pid_antes"
sleep 1
if api_ok; then aviso "a API ainda respondia logo após o kill"; else info "API fora do ar (processo morto)"; fi
if segundos="$(esperar_api 30)"; then
  pid_depois="$(systemctl show -p MainPID --value "$API")"
  info "RECUPEROU em ~$((segundos + 1))s pelo systemd (Restart=on-failure): PID $pid_antes -> $pid_depois"
else
  erro "a API não voltou em 30s"; exit 1
fi
info "log do systemd sobre a queda:"
journalctl -u "$API" -n 6 --no-pager | while read -r linha; do info "  $linha"; done || true

# ---------------------------------------------------------------
# Antes da parte B, espera o monitor registrar a API normal de novo (assim o teste B começa do zero).
info "esperando o monitor confirmar que a API voltou ao normal..."
linhas_a="$(wc -l < "$LOG_MONITOR")"
for _ in $(seq 1 40); do
  grep -q 'api=ok' < <(tail -n +"$((linhas_a + 1))" "$LOG_MONITOR") && break
  sleep 1
done

info "B) Parando a API manualmente com systemctl stop"
auditar "TESTE DE FALHA systemctl stop na API"
linhas_antes="$(wc -l < "$LOG_MONITOR")"
inicio=$SECONDS
systemctl stop "$API"
info "estado da API agora: $(systemctl is-active "$API" || true)  (o systemd não religa sozinho depois de um stop)"
info "esperando o monitor perceber e reiniciar (até 120s)..."
if segundos="$(esperar_api 120)"; then
  info "RECUPEROU em $((SECONDS - inicio))s pelo monitor: health=$(curl -fsS "$URL_HEALTH")"
else
  erro "a API não foi recuperada pelo monitor em 120s"; exit 1
fi
info "o que o monitor registrou no monitor.log:"
tail -n +"$((linhas_antes + 1))" "$LOG_MONITOR" | grep -E 'ALERT|recuperada' | while read -r linha; do info "  $linha"; done || true

info "---- RESULTADO ----"
info "A) kill -9 ........: recuperado pelo systemd"
info "B) systemctl stop .: recuperado pelo monitor"
info "estado final: API=$(systemctl is-active "$API") monitor=$(systemctl is-active "$MONITOR")"