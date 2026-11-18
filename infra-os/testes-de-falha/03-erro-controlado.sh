#!/usr/bin/env bash
# Teste de falha 3 - erro controlado em um script, registrado no log.
# O script executa um passo que funciona e depois um comando que falha DE PROPÓSITO.
# A armadilha de erro do lib.sh registra a linha, o comando e o código no log de
# execução e a auditoria registra o fim com código diferente de zero.
# Uso: sudo bash infra-os/testes-de-falha/03-erro-controlado.sh

DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR_SCRIPT/../scripts/lib.sh"

if [ "${1:-}" = "--falhar" ]; then
  exigir_root
  iniciar_script "$@"
  info "passo 1: tudo certo (este passo funciona)"
  info "passo 2: vou ler um arquivo que não existe, de propósito..."
  cat /var/lib/zeladoria/arquivo-que-nao-existe.txt
  info "passo 3: esta linha NÃO deve aparecer, o script já foi interrompido"
  exit 0
fi

exigir_root
echo "== Executando o script com erro proposital"
codigo=0
bash "${BASH_SOURCE[0]}" --falhar || codigo=$?
echo
echo "== Código de saída do script: $codigo (diferente de zero = erro, como esperado)"
echo
echo "== Registrado em $EXEC_LOG:"
tail -n 5 "$EXEC_LOG"
echo
echo "== Registrado em $AUDIT_LOG:"
tail -n 2 "$AUDIT_LOG"