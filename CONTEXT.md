# CONTEXT.md — estado atual do repositório TermAI

> **Para quem é este arquivo:** agentes e pessoas que vão analisar este repositório. Ele descreve o estado atual do projeto para dar contexto rápido.
>
> **O que ele NÃO é:** não faz parte do TermAI. Nenhum código o lê, não é system prompt, não é configuração e não é memória do agente. Pode ser editado ou apagado sem afetar o programa.
>
> Atualizado em 2026-10-21 (versão `1.21.10.2026`). Se este arquivo divergir do código, o código vence.

## O que é

TermAI é um agente de IA local com interface de terminal (TUI), escrito em Lua 5.4. O alvo principal é Android via Termux; também roda em Linux comum (hoje há uma VPS usada para testes). Não tem daemon, não usa dependências Lua externas, faz HTTP com `curl` (streaming SSE) e persiste sessões em JSONL.

## Como rodar

- Dependências: `lua5.4`, `git`, `curl` e `sh` (o `install.sh` faz `pkg install lua54 git curl` e cria `~/.TermAI`).
- Entry point: `main.lua`. Comandos principais: `tui`, `config`, `status`, `models`, `run`, `cron`, `update` (veja `TermAI help`).
- `TermAI run --prompt "..." [--max-iter N]`: execução não interativa. É o que a CI e os subagentes usam.
- Dados do usuário ficam fora do repositório, em `~/.TermAI/` (por exemplo `config.json`, `agents/<id>/` e `subagents/<runId>/`).

## Mapa do repositório

| Caminho | Conteúdo |
|---|---|
| `agent/` | Loop ReAct, chamadas de API e streaming, compactação, contexto e hooks |
| `tools/` | Ferramentas e execução de comandos. Inclui `tools/subagents/`, `tools/agents/` e `tools/exec/permissions/` |
| `ui/` | TUI: entrada, renderização, bloco de subagentes |
| `commands/` | Comandos da TUI (`/compact`, `/subagents`…) e da CLI |
| `providers/`, `models/` | Provedores de chat e busca, catálogo e resolução de modelos |
| `session/` | Persistência de sessões (JSONL) |
| `config/` | Configuração e migração |
| `memoryflush/` | Memória de longo prazo (flush e arquivamento) |
| `channels/` | Canais alternativos (Telegram) |
| `diag/` | Log de diagnóstico |
| `tests/` | Specs em Lua (uma por arquivo) |
| `e2e/` | Testes ponta a ponta com modelo real (usados pela CI) |
| `docs/` | Documentação de desenho (hoje: `SUBAGENTS.md`) |
| `.github/workflows/` | `tests.yml` e `e2e-kilo.yml` |
| `.claude/`, `.ChatGPT/`, `.grok/`, `.jules/` | Registros e prompts de agentes externos que contribuem com o projeto (não são runtime) |

## Ferramentas do agente (23, registradas em `tools.lua`)

- Arquivos e busca: `Read`, `Write`, `Edit`, `Find`, `Grep`, `List`
- Shell: `Exec`
- Web: `pesquisar_web`, `web_fetch`
- Utilitárias: `calcular`, `todo_write`, `skill`, `restart`
- Memória e sessões: `memory_search`, `sessao_status`, `sessoes_listar`, `sessoes_historico`
- Subagentes: `sessions_spawn`, `subagents_listar`, `subagents_info`, `subagents_log`, `subagents_matar`, `agents_criar`

Permissões ficam em `tools/exec/permissions/`. Ferramentas que não são `Exec` pedem diálogo, exceto `sessions_spawn`, `subagents_listar`, `subagents_info` e `subagents_log`, que são internas e liberadas. `subagents_matar` e `agents_criar` continuam pedindo confirmação.

## Subagentes

O orquestrador chama `sessions_spawn`, que responde `accepted` com um `runId`. Cada subagente roda em um processo próprio (`TermAI run --worker <runId>`), com fila (`maxConcurrent`, `maxChildrenPerAgent`) e timeout (`runTimeoutSeconds`). O resultado entra no contexto do pai no próximo ponto seguro. A TUI mostra um bloco ao vivo e o comando `/subagents` controla as execuções. Um subagente não cria outros subagentes nem agentes. Desenho completo em `docs/SUBAGENTS.md`.

## Convenções do projeto

- Padrão fachada + módulos: um módulo, uma responsabilidade; sem `init.lua`.
- Diretriz de até 150 linhas por arquivo. Ainda existem arquivos acima disso; os maiores hoje são `json.lua` (388), `commands/update.lua` (242) e `agent/loop/tool_runner/executor.lua` (214).
- Comentários em português; emojis do código são preservados. Refatoração estrutural não muda comportamento.
- Commits convencionais, PRs e issues com prefixos como `[INCONSISTÊNCIA]`, `[DOC-GAP]`, `[BUG]`, `[DUPLICAÇÃO]`, `[CÓDIGO-MORTO]` e `[MAPA]`.

## Testes e CI

- Cada spec roda sozinha: `lua5.4 tests/<nome>.lua`. Código de saída diferente de zero é falha. Specs `benchmark*` podem levar minutos.
- `tests.yml` roda todos os specs; a lista de falhas conhecidas (`KNOWN_FAILING`) está vazia.
- `e2e-kilo.yml` testa orquestrador e subagentes com o modelo gratuito `kilo-auto/free`. Roda manualmente, diariamente e em push na branch de subagentes. O job tem `continue-on-error: true`, então um vermelho nele não bloqueia a CI: é preciso ler o log (`ORQUESTRADOR OK` e `SUBAGENTES OK`).

## Versionamento e atualização

- `VERSION` segue `1.<dia>.<mês>.<ano>` (exemplo: `1.21.10.2026`).
- `TermAI update` faz `git fetch origin main` e `git reset --hard origin/main`. Recusa árvore de trabalho suja, a menos que use `--force`. Ou seja, atualiza pelo `main`, não por releases.
- A única release publicada no GitHub é `v1.2.0` (24/07/2026), desatualizada em relação ao `VERSION` (issue #74).

## Registros de contribuição

`.claude/claude.md`, `.ChatGPT/ChatGPT.md` e `.grok/grok.md` guardam o histórico do que cada agente fez. Em `.claude/claude.md` as entradas mais novas ficam no topo.

## Pontos em aberto (2026-10-21)

- Subagentes: falta testar no aparelho e medir a memória por processo para confirmar o padrão de concorrência.
- Caminhos `/home/ubuntu` fixos em `cron.lua` e scripts (issue #83).
- Várias issues `[INCONSISTÊNCIA]`, `[DUPLICAÇÃO]` e `[DOC-GAP]` abertas; veja a lista no GitHub (por exemplo #47, #51, #52, #58, #66, #67, #70, #71, #74, #76).
- O README ainda diz que não há runner de CI formal, mas existe `tests.yml`.
- Arquivos soltos na raiz a revisar: `ChatGPT.md` e `test_sync_check.txt`.
