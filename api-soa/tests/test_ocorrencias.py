import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app

# Banco SÓ para os testes: vive na memória e some quando o teste termina.
engine_teste = create_engine(
    "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
)
SessionTeste = sessionmaker(bind=engine_teste, autoflush=False)

VALIDA = {
    "tipo": "Buraco",
    "descricao": "Buraco grande na Rua das Flores",
    "bairro": "Mooca",
    "latitude": -23.55,
    "longitude": -46.63,
}


@pytest.fixture()
def client():
    """Prepara um banco limpo antes de CADA teste e limpa depois."""
    Base.metadata.create_all(engine_teste)

    def get_db_teste():
        db = SessionTeste()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = get_db_teste
    yield TestClient(app)
    app.dependency_overrides.clear()
    Base.metadata.drop_all(engine_teste)


def registrar(client, **mudancas):
    """Atalho: registra uma ocorrência válida, trocando só o que for pedido."""
    return client.post("/ocorrencias", json={**VALIDA, **mudancas})


def test_health_responde_ok(client):
    resposta = client.get("/health")
    assert resposta.status_code == 200
    assert resposta.json()["status"] == "ok"


def test_registrar_ocorrencia_valida(client):
    resposta = registrar(client)
    assert resposta.status_code == 201
    corpo = resposta.json()
    assert corpo["status"] == "Aberta"
    assert corpo["bairro"] == "Mooca"
    assert "criadaEm" in corpo


def test_rejeita_ocorrencia_sem_tipo(client):
    dados = {k: v for k, v in VALIDA.items() if k != "tipo"}
    resposta = client.post("/ocorrencias", json=dados)
    assert resposta.status_code == 422


def test_rejeita_tipo_invalido(client):
    assert registrar(client, tipo="Barulho").status_code == 422


def test_rejeita_descricao_curta(client):
    assert registrar(client, descricao="ab").status_code == 422


def test_buscar_inexistente_devolve_404(client):
    assert client.get("/ocorrencias/999").status_code == 404


def test_filtrar_por_bairro_e_por_status(client):
    registrar(client, bairro="Mooca")
    segunda = registrar(client, bairro="Pinheiros").json()
    client.patch(f"/ocorrencias/{segunda['id']}/status", json={"status": "Em análise"})

    por_bairro = client.get("/ocorrencias", params={"bairro": "mooca"}).json()
    assert len(por_bairro) == 1

    por_status = client.get("/ocorrencias", params={"status": "Em análise"}).json()
    assert len(por_status) == 1
    assert por_status[0]["bairro"] == "Pinheiros"


def test_atualizar_dados_da_ocorrencia(client):
    criada = registrar(client).json()
    novos = {**VALIDA, "descricao": "Agora o buraco está ainda maior"}
    resposta = client.put(f"/ocorrencias/{criada['id']}", json=novos)
    assert resposta.status_code == 200
    assert resposta.json()["descricao"] == "Agora o buraco está ainda maior"


def test_mudar_status_para_frente(client):
    criada = registrar(client).json()
    resposta = client.patch(
        f"/ocorrencias/{criada['id']}/status", json={"status": "Em andamento"}
    )
    assert resposta.status_code == 200
    assert resposta.json()["status"] == "Em andamento"


def test_nao_pode_voltar_o_status(client):
    criada = registrar(client).json()
    url = f"/ocorrencias/{criada['id']}/status"
    client.patch(url, json={"status": "Resolvida"})
    resposta = client.patch(url, json={"status": "Aberta"})
    assert resposta.status_code == 409


def test_remover_ocorrencia(client):
    criada = registrar(client).json()
    assert client.delete(f"/ocorrencias/{criada['id']}").status_code == 204
    assert client.get(f"/ocorrencias/{criada['id']}").status_code == 404