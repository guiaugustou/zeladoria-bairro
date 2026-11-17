from typing import List, Optional

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy.orm import Session

from app import service
from app.database import get_db
from app.schemas import (
    BairroOut,
    OcorrenciaCreate,
    OcorrenciaOut,
    OcorrenciaUpdate,
    Status,
    StatusUpdate,
)

router_ocorrencias = APIRouter(prefix="/ocorrencias", tags=["Ocorrências"])
router_bairros = APIRouter(prefix="/bairros", tags=["Bairros"])

NAO_ENCONTRADA = {404: {"description": "Ocorrência não encontrada"}}


@router_ocorrencias.post(
    "", response_model=OcorrenciaOut, status_code=201, summary="Registrar uma ocorrência"
)
def criar_ocorrencia(dados: OcorrenciaCreate, db: Session = Depends(get_db)):
    """Registra um problema do bairro (buraco, lixo ou iluminação).
    A ocorrência nasce com o status **Aberta**."""
    return service.registrar(db, dados)


@router_ocorrencias.get(
    "", response_model=List[OcorrenciaOut], summary="Listar ocorrências (com filtros)"
)
def listar_ocorrencias(
    status: Optional[Status] = Query(None, description="Filtra pelo status"),
    bairro: Optional[str] = Query(None, description="Filtra pelo nome do bairro"),
    db: Session = Depends(get_db),
):
    """Lista as ocorrências, das mais novas para as mais antigas.
    Os dois filtros são opcionais e podem ser usados juntos."""
    return service.listar(db, status, bairro)


@router_ocorrencias.get(
    "/{ocorrencia_id}",
    response_model=OcorrenciaOut,
    responses=NAO_ENCONTRADA,
    summary="Buscar uma ocorrência pelo id",
)
def buscar_ocorrencia(ocorrencia_id: int, db: Session = Depends(get_db)):
    return service.buscar(db, ocorrencia_id)


@router_ocorrencias.put(
    "/{ocorrencia_id}",
    response_model=OcorrenciaOut,
    responses=NAO_ENCONTRADA,
    summary="Corrigir os dados de uma ocorrência",
)
def atualizar_ocorrencia(
    ocorrencia_id: int, dados: OcorrenciaUpdate, db: Session = Depends(get_db)
):
    """Troca os dados (tipo, descrição, bairro, local, foto). Não mexe no status."""
    return service.atualizar(db, ocorrencia_id, dados)


@router_ocorrencias.patch(
    "/{ocorrencia_id}/status",
    response_model=OcorrenciaOut,
    responses={**NAO_ENCONTRADA, 409: {"description": "Mudança de status não permitida"}},
    summary="Mudar o status (uso do agente)",
)
def mudar_status_ocorrencia(
    ocorrencia_id: int, dados: StatusUpdate, db: Session = Depends(get_db)
):
    """Regra: o status só avança (Aberta, Em análise, Em andamento, Resolvida).
    Voltar para um status anterior devolve erro 409."""
    return service.mudar_status(db, ocorrencia_id, dados.status)


@router_ocorrencias.delete(
    "/{ocorrencia_id}",
    status_code=204,
    responses=NAO_ENCONTRADA,
    summary="Apagar uma ocorrência",
)
def remover_ocorrencia(ocorrencia_id: int, db: Session = Depends(get_db)):
    service.remover(db, ocorrencia_id)
    return Response(status_code=204)


@router_bairros.get("", response_model=List[BairroOut], summary="Listar os bairros")
def listar_bairros(db: Session = Depends(get_db)):
    """Bairros que já têm pelo menos uma ocorrência registrada."""
    return service.listar_bairros(db)