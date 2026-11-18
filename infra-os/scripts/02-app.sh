#!/usr/bin/env bash
# 02-app.sh - Instala a API (pasta api-soa) e a liga como serviço systemd.
# Faz: dependências, diretórios, variáveis de ambiente, permissões,
#      ambiente Python, migrações do banco e serviço com início automático.
# Uso: sudo bash infra-os/scripts/02-app.sh   (rode antes o 01-infra.sh)
# Pode ser executado várias vezes: cada vez reinstala o código e reinicia a API.

DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR_SCRIPT/lib.sh"
exigir_root
iniciar_script "$@"

# ---- Configurações ----
REPO="$(cd "$DIR_SCRIPT/../.." && pwd)"          # raiz do repositório
ORIGEM="$REPO/api-soa"                           # código da API
UNIT_ORIGEM="$REPO/infra-os/systemd/zeladoria-api.service"
USUARIO_SERVICO="${USUARIO_SERVICO:-zeladoria}"
APP_DIR=/opt/zeladoria/app
VENV_DIR=/opt/zeladoria/venv
ENV_FILE=/etc/zeladoria/zeladoria.env
DB_ARQUIVO=/var/lib/zeladoria/zeladoria.db
SERVICO=zeladoria-api.service
PORTA=8000

# ---------------------------------------------------------------
info "0/6 Verificações iniciais"
[ -d "$ORIGEM" ] || { erro "pasta $ORIGEM não encontrada"; exit 1; }
[ -f "$UNIT_ORIGEM" ] || { erro "arquivo $UNIT_ORIGEM não encontrado"; exit 1; }
id -u "$USUARIO_SERVICO" > /dev/null 2>&1 || { erro "usuário '$USUARIO_SERVICO' não existe: rode antes o 01-infra.sh"; exit 1; }
[ -d /opt/zeladoria ] || { erro "/opt/zeladoria não existe: rode antes o 01-infra.sh"; exit 1; }

# ---------------------------------------------------------------
info "1/6 Dependências do sistema (python3, python3-venv, curl)"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3 python3-venv curl > /dev/null
info "python: $(python3 --version)"

# ---------------------------------------------------------------
info "2/6 Código da aplicação em $APP_DIR"
systemctl stop "$SERVICO" 2>/dev/null || true       # para a API antiga, se existir
rm -rf "$APP_DIR"
install -d "$APP_DIR"
# Copia o código sem o que não vai para produção (ambiente local, caches, banco, testes, prints).
tar -C "$ORIGEM" \
  --exclude='.venv' --exclude='__pycache__' --exclude='.pytest_cache' \
  --exclude='*.db' --exclude='tests' --exclude='evidencias' --exclude='README.md' \
  -cf - . | tar -C "$APP_DIR" -xf -
chown -R root:"$USUARIO_SERVICO" "$APP_DIR"
chmod -R g+rX,o-rwx "$APP_DIR"
info "código copiado: $(ls "$APP_DIR" | tr '\n' ' ')"

# ---------------------------------------------------------------
info "3/6 Variáveis de ambiente em $ENV_FILE"
if [ -f "$ENV_FILE" ]; then
  info "arquivo já existe: mantido como está (suas alterações não são apagadas)"
else
  # A senha/endereço do banco fica aqui, fora do código e do GitHub.
  echo "DATABASE_URL=sqlite:///$DB_ARQUIVO" > "$ENV_FILE"
  info "arquivo criado com DATABASE_URL=sqlite:///$DB_ARQUIVO"
fi
chown root:"$USUARIO_SERVICO" "$ENV_FILE"
chmod 640 "$ENV_FILE"          # dono lê e escreve, o grupo do serviço só lê, os outros nada
info "permissões: $(stat -c '%U:%G %a' "$ENV_FILE")"

# ---------------------------------------------------------------
info "4/6 Ambiente Python (venv) e bibliotecas do requirements.txt"
python3 -m venv "$VENV_DIR"
"$VENV_DIR/bin/pip" install --quiet -r "$APP_DIR/requirements.txt"
info "bibliotecas instaladas: $("$VENV_DIR/bin/pip" list 2>/dev/null | wc -l) pacotes"

# ---------------------------------------------------------------
info "5/6 Migrações do banco (alembic upgrade head)"
set -a; source "$ENV_FILE"; set +a                  # carrega DATABASE_URL
( cd "$APP_DIR" && runuser -u "$USUARIO_SERVICO" -- env DATABASE_URL="$DATABASE_URL" \
    "$VENV_DIR/bin/alembic" upgrade head 2>&1 | while read -r linha; do info "  alembic: $linha"; done )
info "banco em $DB_ARQUIVO: $(stat -c '%U:%G %a' "$DB_ARQUIVO")"

# ---------------------------------------------------------------
info "6/6 Serviço systemd $SERVICO"
install -m 644 "$UNIT_ORIGEM" "/etc/systemd/system/$SERVICO"
systemctl daemon-reload
systemctl enable "$SERVICO" > /dev/null 2>&1       # liga junto com o sistema
systemctl restart "$SERVICO"                       # liga agora

api_respondeu() {
  for _ in $(seq 1 30); do
    curl -fsS --max-time 2 "http://127.0.0.1:$PORTA/health" > /dev/null 2>&1 && return 0
    sleep 1
  done
  return 1
}
if api_respondeu; then
  info "API no ar: $(curl -fsS "http://127.0.0.1:$PORTA/health")"
else
  erro "a API não respondeu em 30 segundos; últimas linhas do log do serviço:"
  journalctl -u "$SERVICO" -n 20 --no-pager || true
  exit 1
fi

info "---- RESUMO ----"
info "serviço ativo .......: $(systemctl is-active "$SERVICO")"
info "início automático ...: $(systemctl is-enabled "$SERVICO")"
info "Swagger .............: http://localhost:$PORTA/docs (abra no navegador do Windows)"
info "logs da API .........: journalctl -u zeladoria-api -n 20 --no-pager"