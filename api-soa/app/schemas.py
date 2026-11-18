from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


class Tipo(str, Enum):
    BURACO = "Buraco"
    LIXO = "Lixo"
    ILUMINACAO = "Iluminação"


class Status(str, Enum):
    ABERTA = "Aberta"
    EM_ANALISE = "Em análise"
    EM_ANDAMENTO = "Em andamento"
    RESOLVIDA = "Resolvida"


class CamelModel(BaseModel):
    """Base de todos os formatos: usa nomes em camelCase (criadaEm, usuarioId),
    como combinado com o grupo, e apaga espaços sobrando nos textos."""

    model_config = ConfigDict(
        alias_generator=to_camel,
        populate_by_name=True,
        from_attributes=True,
        str_strip_whitespace=True,
    )


class OcorrenciaBase(CamelModel):
    tipo: Tipo
    descricao: str = Field(min_length=5, max_length=500)
    bairro: str = Field(min_length=2, max_length=100)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    foto: Optional[str] = Field(default=None, max_length=300)


class OcorrenciaCreate(OcorrenciaBase):
    usuario_id: Optional[int] = None

    # Este exemplo aparece já preenchido no Swagger (/docs)
    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "tipo": "Buraco",
                    "descricao": "Buraco grande na esquina, perigoso para motos",
                    "bairro": "Mooca",
                    "latitude": -23.5505,
                    "longitude": -46.6333,
                    "usuarioId": 1,
                }
            ]
        }
    )


class OcorrenciaUpdate(OcorrenciaBase):
    pass


class StatusUpdate(CamelModel):
    status: Status


class OcorrenciaOut(CamelModel):
    id: int
    tipo: Tipo
    descricao: str
    bairro: str
    latitude: float
    longitude: float
    foto: Optional[str] = None
    status: Status
    usuario_id: Optional[int] = None
    criada_em: datetime
    atualizada_em: datetime


class BairroOut(CamelModel):
    id: int
    nome: str