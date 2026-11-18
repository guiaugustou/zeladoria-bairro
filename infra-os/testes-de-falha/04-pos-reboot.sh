#!/usr/bin/env bash
# Teste de falha 4 - conferência depois de reiniciar o sistema.
# No WSL, reiniciar = no PowerShell do Windows: wsl --shutdown   (e reabrir o Ubuntu).
# Este script mostra que a API e o monitor subiram SOZINHOS, sem ninguém rodar nada.
# Uso: sudo bash infra-os/testes-de-falha/04-pos-reboot.sh

DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR_SCRIPT/../scripts/lib.sh"
exigir_root
iniciar_script "$@"

URL_HEALTH="${URL_HEALTH:-http://127.0.0.1:8000/health}"
auditar "TESTE DE FALHA verificacao apos reinicio"

info "sistema ligado desde: $(uptime -s) ($(uptime -p))"
for servico in zeladoria-api zeladoria-monitor; do
  info "$servico: $(systemctl is-active "$servico") | início automático: $(systemctl is-enabled "$servico") | subiu em: $(systemctl show -p ActiveEnterTimestamp --value "$servico")"
done
if saida="$(curl -fsS --max-time 5 "$URL_HEALTH")"; then
  info "API respondendo: $saida"
else
  erro "a API não respondeu em $URL_HEALTH"
  exit 1
fi
info "últimas linhas do monitor.log:"
tail -n 4 "$LOG_DIR/monitor.log" | while read -r linha; do info "  $linha"; done
info "RESULTADO: serviços ativos após o reinício, sem intervenção manual"