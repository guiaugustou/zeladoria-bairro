#!/usr/bin/env bash
# monitor.sh - Monitora CPU, memória, disco e a API (/health) da Zeladoria do Bairro.
# A cada ciclo grava uma linha INFO com as medidas e, se algum limite for
# ultrapassado, linhas ALERT. Se a API ficar sem responder, reinicia o serviço
# (recuperação automática).
#
# Uso:
#   monitor.sh              roda em loop (é assim que o systemd usa)
#   monitor.sh --uma-vez    faz uma única verificação e sai (bom para testar)
#
# Limites e intervalo vêm de variáveis de ambiente (arquivo /etc/zeladoria/monitor.env).

DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR_SCRIPT/lib.sh"
exigir_root
iniciar_script "$@"

# ---- Configurações (podem ser trocadas por variáveis de ambiente) ----
CPU_LIMITE="${CPU_LIMITE:-80}"                    # % de CPU que dispara alerta
MEM_LIMITE="${MEM_LIMITE:-80}"                    # % de memória em uso
DISCO_LIMITE="${DISCO_LIMITE:-85}"                # % do disco (/) ocupado
INTERVALO="${INTERVALO:-10}"                      # segundos entre as verificações
FALHAS_PARA_REINICIAR="${FALHAS_PARA_REINICIAR:-2}" # falhas seguidas da API antes de reiniciar
URL_HEALTH="${URL_HEALTH:-http://127.0.0.1:8000/health}"
SERVICO_API="${SERVICO_API:-zeladoria-api.service}"
LOG_MONITOR="${LOG_MONITOR:-$LOG_DIR/monitor.log}"

for variavel in CPU_LIMITE MEM_LIMITE DISCO_LIMITE INTERVALO FALHAS_PARA_REINICIAR; do
  case "${!variavel}" in
    ''|*[!0-9]*) erro "$variavel inválido: '${!variavel}' (use um número inteiro)"; exit 1 ;;
  esac
done

FALHAS_API=0

# registrar NIVEL "mensagem": grava no monitor.log e mostra na tela (no systemd, vai para o journal)
registrar() {
  local linha
  linha="$(_agora) [$1] $2"
  echo "$linha" >> "$LOG_MONITOR"
  echo "$linha"
}

# ---- Medidas ----
# CPU: lê /proc/stat duas vezes, com 1 segundo de intervalo, e calcula quanto não foi tempo ocioso.
cpu_uso() {
  local a b c d e f g h total1 ocioso1 total2 ocioso2 dt di
  read -r _ a b c d e f g h _ < /proc/stat
  total1=$((a + b + c + d + e + f + g + h)); ocioso1=$((d + e))
  sleep 1
  read -r _ a b c d e f g h _ < /proc/stat
  total2=$((a + b + c + d + e + f + g + h)); ocioso2=$((d + e))
  dt=$((total2 - total1)); di=$((ocioso2 - ocioso1))
  if [ "$dt" -le 0 ]; then echo 0; else echo $(( (100 * (dt - di)) / dt )); fi
}

# Memória: usado = total - disponível (MemAvailable já desconta o cache que o Linux libera).
mem_uso() {
  local total disponivel
  total="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
  disponivel="$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)"
  echo $(( (100 * (total - disponivel)) / total ))
}

# Disco: porcentagem usada da partição raiz.
disco_uso() {
  df --output=pcent / | tail -n 1 | tr -dc '0-9'
}

api_ok() {
  curl -fsS --max-time 3 "$URL_HEALTH" > /dev/null 2>&1
}

# Espera a API voltar (até 30 s) e mostra quantos segundos levou.
aguardar_api() {
  local t=0
  while [ "$t" -lt 30 ]; do
    if api_ok; then echo "$t"; return 0; fi
    sleep 1
    t=$((t + 1))
  done
  return 1
}

# ---- Alertas ----
checar_limite() {   # checar_limite NOME VALOR LIMITE
  if [ "$2" -ge "$3" ]; then
    registrar ALERT "$1 em $2% (limite $3%)"
    if command -v logger > /dev/null 2>&1; then
      logger -t zeladoria-monitor -p user.warning "ALERT $1 em $2% (limite $3%)" || true
    fi
  fi
}

# Recuperação automática: depois de FALHAS_PARA_REINICIAR falhas seguidas, reinicia o serviço.
tratar_api() {
  if [ "$API_STATUS" = "ok" ]; then
    FALHAS_API=0
    return 0
  fi
  FALHAS_API=$((FALHAS_API + 1))
  registrar ALERT "API sem resposta em $URL_HEALTH (falha $FALHAS_API de $FALHAS_PARA_REINICIAR)"
  if [ "$FALHAS_API" -lt "$FALHAS_PARA_REINICIAR" ]; then
    return 0
  fi
  local estado segundos
  estado="$(systemctl is-active "$SERVICO_API" 2> /dev/null || true)"
  registrar ALERT "reiniciando $SERVICO_API (estado antes: ${estado:-desconhecido})"
  auditar "monitor reiniciou $SERVICO_API apos $FALHAS_API falhas seguidas (estado: ${estado:-desconhecido})"
  if ! systemctl restart "$SERVICO_API"; then
    registrar ERROR "systemctl restart $SERVICO_API falhou"
    return 0
  fi
  if segundos="$(aguardar_api)"; then
    registrar INFO "API recuperada em ${segundos}s após o reinício"
    FALHAS_API=0
  else
    registrar ERROR "API continua sem responder 30s após o reinício"
  fi
}

# Um ciclo completo de verificação.
ciclo() {
  local cpu mem disco
  cpu="$(cpu_uso)" || cpu=0
  mem="$(mem_uso)" || mem=0
  disco="$(disco_uso)" || disco=0
  if api_ok; then API_STATUS=ok; else API_STATUS=falha; fi

  registrar INFO "cpu=${cpu}% mem=${mem}% disco=${disco}% api=${API_STATUS}"
  checar_limite CPU "$cpu" "$CPU_LIMITE"
  checar_limite MEMORIA "$mem" "$MEM_LIMITE"
  checar_limite DISCO "$disco" "$DISCO_LIMITE"
  tratar_api
}

# Parada limpa: o systemd manda SIGTERM no "systemctl stop/restart".
encerrar() {
  registrar INFO "monitor encerrado (sinal recebido)"
  exit 0
}
trap encerrar TERM INT

registrar INFO "monitor iniciado: limites CPU=${CPU_LIMITE}% MEM=${MEM_LIMITE}% DISCO=${DISCO_LIMITE}% | intervalo=${INTERVALO}s | api=${URL_HEALTH}"

if [ "${1:-}" = "--uma-vez" ]; then
  ciclo
  exit 0
fi

while true; do
  ciclo
  sleep "$INTERVALO" &      # "sleep &" + "wait" deixa o SIGTERM interromper a espera na hora
  wait $! || true
done