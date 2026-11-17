from typing import List, Optional

from sqlalchemy.orm import Session

from app import models, repository, schemas
from app.schemas import Status

# A ordem em que uma ocorrência "anda". Só se pode ir para a frente.
ORDEM_STATUS = [Status.ABERTA, Status.EM_ANALISE, Status.EM_ANDAMENTO, Status.RESOLVIDA]


class OcorrenciaNaoEncontrada(Exception):
    """Não existe ocorrência com esse id."""


class TransicaoInvalida(Exception):
    """Tentaram mudar o status de um jeito que as regras não permitem."""


def registrar(db: Session, dados: schemas.OcorrenciaCreate) -> models.Ocorrencia:
    bairro = repository.obter_ou_criar_bairro(db, dados.bairro)
    campos = dados.model_dump(mode="json", exclude={"bairro"})
    return repository.criar(db, campos, bairro)


def listar(
    db: Session, status: Optional[Status], bairro: Optional[str]
) -> List[models.Ocorrencia]:
    valor_status = status.value if status else None
    return repository.listar(db, valor_status, bairro)


def buscar(db: Session, ocorrencia_id: int) -> models.Ocorrencia:
    ocorrencia = repository.obter(db, ocorrencia_id)
    if ocorrencia is None:
        raise OcorrenciaNaoEncontrada(f"Ocorrência {ocorrencia_id} não encontrada.")
    return ocorrencia


def atualizar(
    db: Session, ocorrencia_id: int, dados: schemas.OcorrenciaUpdate
) -> models.Ocorrencia:
    ocorrencia = buscar(db, ocorrencia_id)
    ocorrencia.bairro_obj = repository.obter_ou_criar_bairro(db, dados.bairro)
    for campo, valor in dados.model_dump(mode="json", exclude={"bairro"}).items():
        setattr(ocorrencia, campo, valor)
    return repository.salvar(db, ocorrencia)


def mudar_status(db: Session, ocorrencia_id: int, novo: Status) -> models.Ocorrencia:
    ocorrencia = buscar(db, ocorrencia_id)
    atual = Status(ocorrencia.status)
    if ORDEM_STATUS.index(novo) <= ORDEM_STATUS.index(atual):
        raise TransicaoInvalida(
            f"Não é possível mudar de '{atual.value}' para '{novo.value}': "
            "o status só avança."
        )
    ocorrencia.status = novo.value
    return repository.salvar(db, ocorrencia)


def remover(db: Session, ocorrencia_id: int) -> None:
    ocorrencia = buscar(db, ocorrencia_id)
    repository.remover(db, ocorrencia)


def listar_bairros(db: Session):
    return repository.listar_bairros(db)