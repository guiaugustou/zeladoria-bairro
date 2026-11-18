#!/usr/bin/env bash
# 03-monitor.sh - Instala o monitoramento como serviço systemd (zeladoria-monitor).
# Faz: copia monitor.sh para /opt/zeladoria/bin, cria o arquivo de limites,
#      configura a rotação dos logs e liga o serviço com início automático.
# Uso: sudo bash infra-os/scripts/03-monitor.sh   (rode antes o 01 e o 02)
# Pode ser executado várias vezes: cada vez reinstala o monitor e reinicia o serviço.

DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR_SCRIPT/lib.sh"
exigir_root
iniciar_script "$@"

# ---- Configurações ----
REPO="$(cd "$DIR_SCRIPT/../.." && pwd)"
UNIT_ORIGEM="$REPO/infra-os/systemd/zeladoria-monitor.service"
BIN_DIR=/opt/zeladoria/bin
CONF_MONITOR=/etc/zeladoria/monitor.env
LOG_MONITOR="$LOG_DIR/monitor.log"
SERVICO=zeladoria-monitor.service

# ---------------------------------------------------------------
info "0/4 Verificações iniciais"
[ -f "$DIR_SCRIPT/monitor.sh" ] || { erro "monitor.sh não encontrado em $DIR_SCRIPT"; exit 1; }
[ -f "$UNIT_ORIGEM" ] || { erro "arquivo $UNIT_ORIGEM não encontrado"; exit 1; }
[ -d /opt/zeladoria ] || { erro "/opt/zeladoria não existe: rode antes o 01-infra.sh"; exit 1; }
if [ ! -f /etc/systemd/system/zeladoria-api.service ]; then
  aviso "a API ainda não está instalada como serviço (rode o 02-app.sh); o monitor vai alertar até ela existir"
fi

# ---------------------------------------------------------------
info "1/4 Programas do monitor em $BIN_DIR"
apt-get -o DPkg::Lock::Timeout=300 update -qq
DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y -qq curl logrotate > /dev/null
install -d -m 755 -o root -g root "$BIN_DIR"
install -m 755 -o root -g root "$DIR_SCRIPT/monitor.sh" "$DIR_SCRIPT/lib.sh" "$BIN_DIR/"
info "instalados: $(ls "$BIN_DIR" | tr '\n' ' ')"

# ---------------------------------------------------------------
info "2/4 Limites do monitoramento em $CONF_MONITOR"
if [ -f "$CONF_MONITOR" ]; then
  info "arquivo já existe: mantido como está"
else
  cat > "$CONF_MONITOR" <<'CONF'
# Limites do monitoramento (em %), intervalo (em segundos) e recuperação da API.
# Depois de mudar um valor: sudo systemctl restart zeladoria-monitor
CPU_LIMITE=80
MEM_LIMITE=80
DISCO_LIMITE=85
INTERVALO=10
FALHAS_PARA_REINICIAR=2
CONF
  info "arquivo criado com os limites padrão"
fi
chown root:root "$CONF_MONITOR"
chmod 644 "$CONF_MONITOR"
info "limites em uso: $(grep -v '^#' "$CONF_MONITOR" | tr '\n' ' ')"

# ---------------------------------------------------------------
info "3/4 Rotação dos logs (logrotate)"
# "su root zeladoria-ops" é exigido porque a pasta de logs é gravável pelo grupo de operação.
cat > /etc/logrotate.d/zeladoria <<EOF2
$LOG_DIR/*.log {
    su root zeladoria-ops
    weekly
    rotate 4
    compress
    missingok
    notifempty
    copytruncate
}
EOF2
if logrotate --debug /etc/logrotate.d/zeladoria > /dev/null 2>&1; then
  info "configuração do logrotate validada (/etc/logrotate.d/zeladoria)"
else
  aviso "não consegui validar o logrotate; os logs funcionam, só a rotação fica sem teste"
fi

# ---------------------------------------------------------------
info "4/4 Serviço systemd $SERVICO"
: >> "$LOG_MONITOR"
linhas_antes="$(wc -l < "$LOG_MONITOR")"
install -m 644 "$UNIT_ORIGEM" "/etc/systemd/system/$SERVICO"
systemctl daemon-reload
systemctl enable "$SERVICO" > /dev/null 2>&1      # liga junto com o sistema
systemctl restart "$SERVICO"                      # liga agora

# Espera o monitor escrever as primeiras linhas no monitor.log (até 20 s).
for _ in $(seq 1 20); do
  [ "$(wc -l < "$LOG_MONITOR")" -ge $((linhas_antes + 2)) ] && break
  sleep 1
done
if ! systemctl is-active --quiet "$SERVICO"; then
  erro "o serviço não ficou ativo; últimas linhas do log:"
  journalctl -u "$SERVICO" -n 20 --no-pager || true
  exit 1
fi

info "---- RESUMO ----"
info "serviço ativo .......: $(systemctl is-active "$SERVICO")"
info "início automático ...: $(systemctl is-enabled "$SERVICO")"
info "últimas linhas do monitor.log:"
tail -n 3 "$LOG_MONITOR" | while read -r linha; do info "  $linha"; done
info "acompanhar ao vivo ..: tail -f $LOG_MONITOR"
info "controlar ...........: sudo systemctl stop|start|restart zeladoria-monitor"