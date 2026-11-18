#!/usr/bin/env bash
# lib.sh - funções comuns aos scripts do projeto (log, auditoria e tratamento de erro).
# Este arquivo não é executado sozinho: os outros scripts fazem "source" dele.

LOG_DIR="${LOG_DIR:-/var/log/zeladoria}"
EXEC_LOG="$LOG_DIR/execucao.log"      # o que cada script fez, passo a passo
AUDIT_LOG="$LOG_DIR/auditoria.log"    # quem rodou o quê, e se terminou bem
SCRIPT_NAME="$(basename "$0")"
QUEM="${SUDO_USER:-$(id -un)}"        # se foi com sudo, mostra o usuário original

_agora() { date '+%Y-%m-%d %H:%M:%S'; }

# log NIVEL "mensagem": mostra na tela e grava no log de execução
log() {
  local nivel="$1"; shift
  local linha
  linha="$(_agora) [$nivel] [$SCRIPT_NAME] $*"
  echo "$linha"
  echo "$linha" >> "$EXEC_LOG" 2>/dev/null || true
}
info()  { log INFO "$@"; }
aviso() { log WARN "$@"; }
erro()  { log ERROR "$@"; }

# auditar "texto": registra no log de auditoria quem fez a ação
auditar() {
  echo "$(_agora) usuario=$QUEM script=$SCRIPT_NAME acao=\"$*\"" >> "$AUDIT_LOG" 2>/dev/null || true
}

exigir_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Este script precisa de root. Rode: sudo bash $0" >&2
    exit 1
  fi
}

preparar_logs() {
  mkdir -p "$LOG_DIR"
  touch "$EXEC_LOG" "$AUDIT_LOG"
}

# Chamado quando algum comando falha: registra a linha e o comando e encerra.
_ao_falhar() {
  local codigo="$1" linha="$2" comando="$3"
  erro "falhou na linha $linha (código $codigo): $comando"
}

# Chamado sempre que o script termina (com sucesso ou com erro).
_ao_sair() {
  local codigo=$?
  if [ "$codigo" -eq 0 ]; then
    info "terminou com sucesso"
  else
    erro "terminou com erro (código $codigo)"
  fi
  auditar "FIM codigo=$codigo"
}

# iniciar_script "$@": liga o modo seguro, o registro de erros e a auditoria.
#   -E/-e : qualquer comando que falhar interrompe o script
#   -u    : variável não definida é erro
#   pipefail: erro dentro de um "cmd1 | cmd2" também conta
iniciar_script() {
  set -Eeuo pipefail
  preparar_logs
  trap '_ao_falhar $? $LINENO "$BASH_COMMAND"' ERR
  trap _ao_sair EXIT
  auditar "INICIO args=[$*]"
  info "iniciando (usuário: $QUEM)"
}