# Zeladoria do Bairro

Projeto da Global Solution CitizenTech 2026.2 (FIAP, Engenharia de Software, 3º ano).

## Ficha da CitizenTech

| Item | Descrição |
| --- | --- |
| Nome | Zeladoria do Bairro |
| Cidade | São Paulo |
| Cidadão beneficiado | Morador que convive com o problema (e o agente que atende as ocorrências) |
| Problema, em uma frase | O morador não tem um jeito simples de registrar problemas do espaço público do bairro e não sabe se o chamado foi atendido. |
| Como funciona | Registrar, acompanhar e atualizar ocorrências, com alerta automático de poste apagado (IoT). |
| O que cada parte faz | App mobile: o morador registra e acompanha. Esta API (SOA): guarda as ocorrências e aplica as regras de status. Serviço de usuários (C#): perfis e histórico. Sensor IoT: poste apagado abre ocorrência. ML: estima o tempo de resolução. Infraestrutura Linux (OS): hospeda e monitora a API. |
| Link do repositório | https://github.com/guiaugustou/zeladoria-bairro |
| Indicador de impacto | Tempo médio de resolução das ocorrências e % de ocorrências resolvidas. |
| ODS conectados | ODS 11 (cidades e comunidades sustentáveis): melhora o espaço público e a participação do morador. ODS 9 (indústria, inovação e infraestrutura): usa tecnologia para manter a infraestrutura urbana. |
| Dados | Dados simulados; nenhum dado pessoal real. |

## Integrantes

- Augusto Rocha Silva - RM556316
- Erik Yuuta Goto - RM558076
- Guilherme Vieira Augusto - RM557264
- Wendell dos Santos Silva - RM558859

## Estrutura do repositório

| Pasta | O que tem | Disciplina |
| --- | --- | --- |
| [api-soa](api-soa/README.md) | API REST de ocorrências: FastAPI, banco de dados, migrações, Swagger e testes | Arquitetura Orientada a Serviços (SOA) e Web Services |
| [infra-os](infra-os/README.md) | Scripts Bash, serviços systemd, monitoramento e testes de falha da infraestrutura Linux que hospeda a API | Operating Systems |

## Uso de IA

Registrado em [prompts.md](prompts.md).