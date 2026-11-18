#!/usr/bin/env bash
# Teste de falha 2 - sobrecarga de CPU e de memória, e o alerta do monitor.
#   CPU:     enche todos os núcleos por 25 s; o serviço de monitoramento registra ALERT.
#   Memória: ocupa uma parte da RAM; o limite é reduzido SÓ nesta demonstração, para não
#            esgotar a memória da máquina (o limite padrão de 80% exigiria quase toda a RAM).
# Uso: sudo bash infra-os/testes-de-falha/02-carga.sh   (precisa do 03-monitor.sh instalado)

DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR_SCRIPT/../scripts/lib.sh"
exigir_root
iniciar_script "$@"

MONITOR=zeladoria-monitor.service
LOG_MONITOR="$LOG_DIR/monitor.log"
MONITOR_SH="${MONITOR_SH:-/opt/zeladoria/bin/monitor.sh}"
SEGUNDOS_CPU=25

systemctl is-active --quiet "$MONITOR" || { erro "o monitor não está ativo: rode antes o 03-monitor.sh"; exit 1; }
command -v python3 > /dev/null || { erro "python3 não encontrado"; exit 1; }

# ---------------------------------------------------------------
info "1/2 Carga de CPU: $(nproc) núcleo(s) a 100% por ${SEGUNDOS_CPU}s"
auditar "TESTE DE FALHA carga de CPU"
linhas_antes="$(wc -l < "$LOG_MONITOR")"
for _ in $(seq 1 "$(nproc)"); do
  timeout "$SEGUNDOS_CPU" yes > /dev/null &
done
info "carga ligada; esperando o serviço de monitoramento perceber..."
sleep 16
info "linhas que o monitor gravou durante a carga:"
tail -n +"$((linhas_antes + 1))" "$LOG_MONITOR" | grep -E 'cpu=|ALERT' | while read -r linha; do info "  $linha"; done || true
wait
info "carga de CPU encerrada"
if grep -q 'ALERT.*CPU' < <(tail -n +"$((linhas_antes + 1))" "$LOG_MONITOR"); then
  info "RESULTADO CPU: alerta registrado"
else
  aviso "RESULTADO CPU: nenhum alerta (a CPU pode não ter passado do limite)"
fi

# ---------------------------------------------------------------
info "2/2 Carga de memória"
auditar "TESTE DE FALHA carga de memoria"
sleep 12   # deixa a CPU se acalmar
total_kb="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
base="$(awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2} END {print int(100*(t-a)/t)}' /proc/meminfo)"
mb=$((total_kb * 12 / 100 / 1024))                 # 12% da RAM
limite=$((base + 5))                               # limite só para esta demonstração
info "RAM total: $((total_kb / 1024)) MB | em uso agora: ${base}% | vou ocupar ~${mb} MB | limite de demonstração: ${limite}%"
python3 -c "
import time
bloco = bytearray(b'a') * ($mb * 1024 * 1024)   # escreve de verdade na memória
time.sleep(20)
" &
sleep 4
info "memória ocupada; rodando uma verificação do monitor com o limite reduzido:"
MEM_LIMITE="$limite" bash "$MONITOR_SH" --uma-vez 2>&1 | grep -E 'cpu=|ALERT' | while read -r linha; do info "  $linha"; done || true
wait
info "memória liberada: $(awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2} END {print int(100*(t-a)/t)}' /proc/meminfo)% em uso"

info "---- RESULTADO ----"
info "CPU e memória sobrecarregadas; alertas gravados em $LOG_MONITOR"