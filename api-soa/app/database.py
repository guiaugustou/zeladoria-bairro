from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from app.config import DATABASE_URL

# O SQLite precisa desta opção extra; outros bancos (PostgreSQL) não.
connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}

# engine = a "ligação" com o banco. SessionLocal = fábrica de "conversas" com ele.
engine = create_engine(DATABASE_URL, connect_args=connect_args)
SessionLocal = sessionmaker(bind=engine, autoflush=False)


class Base(DeclarativeBase):
    """Toda tabela do projeto herda desta classe."""


def get_db():
    """Entrega uma conexão para cada requisição e fecha no final."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()