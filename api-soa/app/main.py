from fastapi import Depends, FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.orm import Session

from app import service
from app.database import get_db
from app.routes import router_bairros, router_ocorrencias

app = FastAPI(
    title="Zeladoria do Bairro - API de Ocorrências",
    description=(
        "Serviço do projeto CitizenTech (Global Solution 2026.2). "
        "O morador registra problemas do bairro e o agente atualiza o andamento."
    ),
    version="1.0.0",
)

# Deixa o app do celular (Expo) e outros serviços do grupo chamarem esta API.
app.add_middleware(
    CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"]
)

app.include_router(router_ocorrencias)
app.include_router(router_bairros)


@app.exception_handler(service.OcorrenciaNaoEncontrada)
async def tratar_nao_encontrada(request: Request, erro: service.OcorrenciaNaoEncontrada):
    return JSONResponse(status_code=404, content={"detail": str(erro)})


@app.exception_handler(service.TransicaoInvalida)
async def tratar_transicao_invalida(request: Request, erro: service.TransicaoInvalida):
    return JSONResponse(status_code=409, content={"detail": str(erro)})


@app.get("/health", tags=["Saúde"], summary="A API e o banco estão de pé?")
def health(db: Session = Depends(get_db)):
    """Usado pelo monitoramento (disciplina de OS) para saber se está tudo bem."""
    try:
        db.execute(text("SELECT 1"))
    except Exception:
        raise HTTPException(status_code=503, detail="Banco de dados indisponível")
    return {"status": "ok", "banco": "ok"}