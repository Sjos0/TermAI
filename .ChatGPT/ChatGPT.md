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
- Pull Request: [#369](https://github.com/Sjos0/TermAI/pull/369)
- Commit de implementação: `783d0e4`
- Fonte canônica da versão: `VERSION`

### Escopo

- Migração compatível de `apiKey` singular para `apiKeys` com rotação persistente por provedor.
- Micro fallback usa `request.max_retries` e os tempos de espera já existentes; esgota as chaves antes do macro fallback de modelos/provedores, também no caminho síncrono de recuperação do streaming.
- Gestão TUI/CLI de chaves e modelos fallback, teste sequencial, mensagens de transparência e redaction de segredos.
- Testes e documentação técnica adicionados.

A versão não foi incrementada porque o histórico do repositório separa feature PRs das PRs dedicadas de release; não houve publicação de release nesta mudança.

---

## Atualização pós revisão do Bugs Hunter — 2026-11-21

A revisão da PR #369 não encontrou defeito funcional bloqueante confirmado. Os apontamentos de UX/diagnóstico foram tratados na mesma branch e PR:

- Mensagem de rotação de chave passou a usar o bloco compartilhado de status da TUI, com limpeza integrada ao fluxo de retry.
- Saúde das chaves passou a exibir data/hora compacta e explicitamente UTC.
- Erros dos testes de conexão continuam disponíveis para diagnóstico, mas são achatados em uma linha, removem sequências de controle ANSI/terminal e têm a API key redigida após a sanitização.
- A semântica de uma tentativa sem credencial para provedores sem chave foi documentada e preservada.

Validação local: 143 specs Lua passaram, além do teste PTY, sintaxe de todos os arquivos Lua e `git diff --check`. O benchmark `tests/benchmark_bolt.lua` foi omitido da rodada local por custo de CPU; permanece incluído no workflow do GitHub Actions.

Estado: PR #369 aberta, sem merge; `VERSION` continua `1.39.0`, sem bump de feature.
