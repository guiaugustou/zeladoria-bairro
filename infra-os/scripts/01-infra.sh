#!/usr/bin/env bash
# 01-infra.sh - Prepara a infraestrutura do servidor:
#   hostname, IP e rede, DNS, usuários e permissões.
# Uso: sudo bash infra-os/scripts/01-infra.sh
# Pode ser executado várias vezes (o resultado é sempre o mesmo).

DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR_SCRIPT/lib.sh"
exigir_root
iniciar_script "$@"

# ---- Configurações (podem ser trocadas ao chamar o script) ----
HOSTNAME_ALVO="${HOSTNAME_ALVO:-zeladoria-srv}"
DNS_RESERVA="${DNS_RESERVA:-1.1.1.1 8.8.8.8}"
USUARIO_SERVICO="${USUARIO_SERVICO:-zeladoria}"     # quem executa a API
GRUPO_OPERACAO="${GRUPO_OPERACAO:-zeladoria-ops}"   # quem opera o servidor
WSL_CONF="${WSL_CONF:-/etc/wsl.conf}"
RESOLV_CONF="${RESOLV_CONF:-/etc/resolv.conf}"

# Estamos dentro do WSL? (o kernel do WSL se identifica como "microsoft")
em_wsl() { grep -qi microsoft /proc/version; }

# Grava uma opção no /etc/wsl.conf sem apagar as que já existem.
wsl_conf_definir() {   # uso: wsl_conf_definir secao chave valor
  python3 - "$WSL_CONF" "$1" "$2" "$3" <<'PY'
import configparser, sys
arquivo, secao, chave, valor = sys.argv[1:5]
cfg = configparser.ConfigParser()
cfg.optionxform = str          # mantém maiúsculas e minúsculas das chaves
cfg.read(arquivo)
if not cfg.has_section(secao):
    cfg.add_section(secao)
cfg.set(secao, chave, valor)
with open(arquivo, "w") as f:
    cfg.write(f, space_around_delimiters=False)
PY
}

# ---------------------------------------------------------------
info "0/4 Ferramentas de rede (curl, iproute2, iputils-ping)"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl iproute2 iputils-ping > /dev/null

# ---------------------------------------------------------------
info "1/4 Hostname"
hostname_atual="$(hostname)"
if [ "$hostname_atual" != "$HOSTNAME_ALVO" ]; then
  if ! hostnamectl set-hostname "$HOSTNAME_ALVO" 2>/dev/null; then
    hostname "$HOSTNAME_ALVO"
    echo "$HOSTNAME_ALVO" > /etc/hostname
  fi
  info "hostname alterado de '$hostname_atual' para '$HOSTNAME_ALVO'"
else
  info "hostname já é '$HOSTNAME_ALVO'"
fi
# Sem esta linha o sudo reclama que não resolve o nome da própria máquina.
grep -qw "$HOSTNAME_ALVO" /etc/hosts || echo "127.0.1.1 $HOSTNAME_ALVO" >> /etc/hosts
# O WSL recria o hostname a cada partida; esta opção fixa o nome escolhido.
if em_wsl; then
  wsl_conf_definir network hostname "$HOSTNAME_ALVO"
fi

# ---------------------------------------------------------------
info "2/4 IP e rede"
ip -brief addr | while read -r linha; do info "  interface: $linha"; done
gateway="$(ip route show default | awk '/^default/ {print $3; exit}')"
info "gateway padrão: ${gateway:-nenhum}"
if [ -n "$gateway" ] && ping -c1 -W2 "$gateway" > /dev/null 2>&1; then
  info "gateway respondeu ao ping"
else
  aviso "gateway não respondeu ao ping (em rede virtual isso pode ser normal)"
fi
if ping -c1 -W3 1.1.1.1 > /dev/null 2>&1; then
  info "internet OK (1.1.1.1 respondeu)"
else
  aviso "1.1.1.1 não respondeu (o ping pode estar bloqueado nesta rede)"
fi
if em_wsl; then
  info "ambiente WSL: o IP e a rede são gerenciados pelo Windows; o script registra e valida, não altera"
else
  info "ambiente VM: rede por DHCP (modo bridge); o script registra e valida"
fi

# ---------------------------------------------------------------
info "3/4 DNS"
if em_wsl; then
  # O WSL gera o resolv.conf sozinho. Desligamos isso para o nosso valer,
  # mantendo os servidores atuais (que já funcionam) e acrescentando reservas.
  wsl_conf_definir network generateResolvConf false
  [ -e "$RESOLV_CONF.bak-zeladoria" ] || cp -L "$RESOLV_CONF" "$RESOLV_CONF.bak-zeladoria"
  atuais="$(awk '/^nameserver/ {print $2}' "$RESOLV_CONF" || true)"
  extras="$(grep -E '^(search|options)' "$RESOLV_CONF" || true)"
  {
    echo "# gerado por 01-infra.sh (servidores atuais + reservas)"
    [ -n "$extras" ] && echo "$extras"
    lista="$atuais"
    for dns in $DNS_RESERVA; do
      echo "$lista" | grep -qx "$dns" || lista="$lista"$'\n'"$dns"
    done
    echo "$lista" | awk 'NF {print "nameserver " $1}'
  } > "$RESOLV_CONF.novo"
  rm -f "$RESOLV_CONF"
  mv "$RESOLV_CONF.novo" "$RESOLV_CONF"
  info "resolv.conf atualizado (cópia do original em $RESOLV_CONF.bak-zeladoria)"
else
  mkdir -p /etc/systemd/resolved.conf.d
  printf '[Resolve]\nDNS=%s\n' "$DNS_RESERVA" > /etc/systemd/resolved.conf.d/zeladoria.conf
  systemctl restart systemd-resolved 2>/dev/null || aviso "systemd-resolved não está ativo; DNS não alterado"
fi
if getent hosts github.com > /dev/null; then
  info "resolução de nomes OK: github.com -> $(getent hosts github.com | awk 'NR==1 {print $1}')"
else
  aviso "não foi possível resolver github.com"
fi

# ---------------------------------------------------------------
info "4/4 Usuários e permissões"
getent group "$USUARIO_SERVICO" > /dev/null || groupadd --system "$USUARIO_SERVICO"
id -u "$USUARIO_SERVICO" > /dev/null 2>&1 || useradd --system --gid "$USUARIO_SERVICO" \
  --home-dir /opt/zeladoria --no-create-home --shell /usr/sbin/nologin "$USUARIO_SERVICO"
getent group "$GRUPO_OPERACAO" > /dev/null || groupadd "$GRUPO_OPERACAO"
if [ "$QUEM" != "root" ]; then
  usermod -aG "$GRUPO_OPERACAO" "$QUEM"
  info "usuário '$QUEM' incluído no grupo '$GRUPO_OPERACAO' (vale a partir do próximo login)"
fi

criar_dir() {   # uso: criar_dir dono grupo modo caminho
  install -d -o "$1" -g "$2" "$4"
  chmod "$3" "$4"
  info "  $4 (dono=$1 grupo=$2 modo=$3)"
}
criar_dir root "$USUARIO_SERVICO" 750 /opt/zeladoria            # código da aplicação (só leitura para o serviço)
criar_dir root "$USUARIO_SERVICO" 750 /etc/zeladoria            # configuração e segredos
criar_dir "$USUARIO_SERVICO" "$USUARIO_SERVICO" 750 /var/lib/zeladoria   # dados (banco)
criar_dir root "$GRUPO_OPERACAO" 2775 /var/log/zeladoria        # logs (operadores podem ler e gravar)
chgrp "$GRUPO_OPERACAO" "$EXEC_LOG" "$AUDIT_LOG"
chmod 664 "$EXEC_LOG" "$AUDIT_LOG"

# ---------------------------------------------------------------
info "---- RESUMO ----"
info "hostname ........: $(hostname)"
info "IPs .............: $(hostname -I)"
info "DNS .............: $(awk '/^nameserver/ {printf "%s ", $2}' "$RESOLV_CONF")"
info "usuário serviço .: $(id "$USUARIO_SERVICO")"
info "grupo operação ..: $(getent group "$GRUPO_OPERACAO")"
if em_wsl; then
  info "no WSL, para o hostname e o DNS valerem depois de reiniciar, rode no PowerShell: wsl --shutdown"
fi