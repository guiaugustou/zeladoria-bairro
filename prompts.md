# Prompts de IA usados no projeto

Ferramenta: Claude (Anthropic). Cada linha abaixo é um pedido importante; o código gerado foi executado e testado no meu computador, e eu sei explicar o que cada parte faz.

| Data | O que pedi | O que a IA respondeu (resumo) | O que eu entendi e ajustei |
| --- | --- | --- | --- |
| 11/11/2026 | Pedi ajuda para entender o briefing da GS e planejar a API de ocorrências (SOA) | Plano em etapas com FastAPI, SQLAlchemy, Alembic e pytest, usando os nomes do vocabulário comum do grupo | Entendi as camadas: routes recebe os pedidos, service guarda as regras e repository fala com o banco |
| 12/11/2026 | Pedi as migrações do banco, incluindo uma segunda para a coluna foto | Comandos `alembic revision --autogenerate` e `alembic upgrade head` | Entendi que a migração guarda a mudança do banco em um arquivo versionado e que a foto foi acrescentada sem perder os dados |
| 16/11/2026 | Pedi os testes automáticos da API | 11 testes com pytest, banco em memória e `dependency_overrides` | Entendi que cada teste usa um banco novo, que some no fim, e não mexe no zeladoria.db |
| 17/11/2026 | Pedi ajuda no teste manual da API pelo Swagger | Roteiro com POST, GET com filtros, PATCH de status e os erros 404, 409 e 422 | Entendi o que cada código significa e guardei prints como evidência |
| 17/11/2026 | Pedi ajuda com requirements.txt, .gitignore, README com a Ficha e este prompts.md | Modelos dos arquivos e para que serve cada um | Entendi que o .gitignore evita enviar o .venv e o banco, e que o requirements.txt reinstala tudo com um comando |