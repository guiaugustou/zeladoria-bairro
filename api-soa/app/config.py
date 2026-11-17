import os

# Endereço do banco de dados.
# Se a variável de ambiente DATABASE_URL não existir, usamos um arquivo SQLite
# local (zeladoria.db). No OS, vamos trocar para PostgreSQL só mudando essa variável.
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./zeladoria.db")