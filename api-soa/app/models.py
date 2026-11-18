from datetime import datetime
from typing import List, Optional

from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Bairro(Base):
    __tablename__ = "bairros"

    id: Mapped[int] = mapped_column(primary_key=True)
    nome: Mapped[str] = mapped_column(String(100), unique=True)

    ocorrencias: Mapped[List["Ocorrencia"]] = relationship(back_populates="bairro_obj")


class Ocorrencia(Base):
    __tablename__ = "ocorrencias"

    id: Mapped[int] = mapped_column(primary_key=True)
    tipo: Mapped[str] = mapped_column(String(20))
    descricao: Mapped[str] = mapped_column(String(500))
    latitude: Mapped[float]
    longitude: Mapped[float]
    status: Mapped[str] = mapped_column(String(20), default="Aberta")
    usuario_id: Mapped[Optional[int]] = mapped_column(nullable=True)
    criada_em: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    atualizada_em: Mapped[datetime] = mapped_column(
        DateTime, server_default=func.now(), onupdate=func.now()
    )
    foto: Mapped[Optional[str]] = mapped_column(String(300), nullable=True)

    # Ligação com a tabela de bairros (cada ocorrência pertence a 1 bairro)
    bairro_id: Mapped[int] = mapped_column(ForeignKey("bairros.id"))
    bairro_obj: Mapped[Bairro] = relationship(back_populates="ocorrencias")

    @property
    def bairro(self) -> str:
        """O app do celular quer só o NOME do bairro, não o objeto inteiro."""
        return self.bairro_obj.nome