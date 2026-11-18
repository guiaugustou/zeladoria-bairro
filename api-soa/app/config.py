import os

# Endereço do banco de dados.
# Se a variável de ambiente DATABASE_URL não existir, usamos um arquivo SQLite
# local (zeladoria.db). Na infraestrutura (OS), ela é definida em /etc/zeladoria/zeladoria.env.
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./zeladoria.db")