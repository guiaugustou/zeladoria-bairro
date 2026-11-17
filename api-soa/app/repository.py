from typing import List, Optional

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app import models


def obter_ou_criar_bairro(db: Session, nome: str) -> models.Bairro:
    """Procura o bairro pelo nome (sem ligar para maiúsculas); se não existir, cria."""
    bairro = db.scalar(
        select(models.Bairro).where(func.lower(models.Bairro.nome) == nome.lower())
    )
    if bairro is None:
        bairro = models.Bairro(nome=nome)
        db.add(bairro)
        db.flush()  # gera o id agora, mas ainda não finaliza a transação
    return bairro


def criar(db: Session, campos: dict, bairro: models.Bairro) -> models.Ocorrencia:
    ocorrencia = models.Ocorrencia(**campos, bairro_obj=bairro)
    db.add(ocorrencia)
    db.commit()
    db.refresh(ocorrencia)
    return ocorrencia


def obter(db: Session, ocorrencia_id: int) -> Optional[models.Ocorrencia]:
    return db.get(models.Ocorrencia, ocorrencia_id)


def listar(
    db: Session, status: Optional[str] = None, bairro: Optional[str] = None
) -> List[models.Ocorrencia]:
    consulta = select(models.Ocorrencia).join(models.Bairro)
    if status:
        consulta = consulta.where(models.Ocorrencia.status == status)
    if bairro:
        consulta = consulta.where(func.lower(models.Bairro.nome) == bairro.lower())
    consulta = consulta.order_by(models.Ocorrencia.id.desc())  # mais novas primeiro
    return list(db.scalars(consulta))


def salvar(db: Session, ocorrencia: models.Ocorrencia) -> models.Ocorrencia:
    db.commit()
    db.refresh(ocorrencia)
    return ocorrencia


def remover(db: Session, ocorrencia: models.Ocorrencia) -> None:
    db.delete(ocorrencia)
    db.commit()


def listar_bairros(db: Session) -> List[models.Bairro]:
    return list(db.scalars(select(models.Bairro).order_by(models.Bairro.nome)))