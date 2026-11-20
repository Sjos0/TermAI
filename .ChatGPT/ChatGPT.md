# TermAI — Histórico de registros do ChatGPT

## Registro histórico de versão — PR #80

Data: 2026-10-08
Versão canônica à época: 1.8.10.2026
Versão anterior à época: 1.26.09.2026

## Registro

A versão canônica foi atualizada para `1.8.10.2026`, seguindo o padrão histórico `1.<dia>.<mês>.<ano>` usado pelo projeto.

## Rastreabilidade

- Issue: #79
- Branch: `fix/79-version-2026-10-08-chatgpt-record`
- Pull Request: #80
- Fonte canônica: `VERSION`

## Estado do release

O release/tag público correspondente deve espelhar `VERSION` como `v1.8.10.2026`. A publicação do release e o merge da PR permanecem sujeitos à aprovação humana, conforme a função do Agente Implementador.

---

## Registro de implementação — Issue #368

Data: 2026-11-20
Versão canônica mantida: `1.39.0` (sem bump nesta feature PR)

### Rastreabilidade

- Issue: #368 — Multi-API-key por provedor + Micro Fallback
- Branch: `feature/368-multi-api-key-micro-fallback`
- Pull Request: a registrar após abertura
- Fonte canônica da versão: `VERSION`

### Escopo

- Migração compatível de `apiKey` singular para `apiKeys` com rotação persistente por provedor.
- Micro fallback usa `request.max_retries` e os tempos de espera já existentes; esgota as chaves antes do macro fallback de modelos/provedores, também no caminho síncrono de recuperação do streaming.
- Gestão TUI/CLI de chaves e modelos fallback, teste sequencial, mensagens de transparência e redaction de segredos.
- Testes e documentação técnica adicionados.

A versão não foi incrementada porque o histórico do repositório separa feature PRs das PRs dedicadas de release; não houve publicação de release nesta mudança.
