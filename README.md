# 🦇 TermAI — Harness de Engenharia para Agentes Inteligentes

<p align="center">
  <a href="https://github.com/Sjos0/TermAI/releases"><img src="https://img.shields.io/github/v/release/Sjos0/TermAI?include_prereleases&style=for-the-badge" alt="GitHub release"></a>
  <a href="https://github.com/Sjos0/TermAI/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge" alt="MIT License"></a>
  <a href="https://github.com/Sjos0/TermAI"><img src="https://img.shields.io/github/stars/Sjos0/TermAI?style=for-the-badge" alt="GitHub stars"></a>
  <a href="https://www.instagram.com/sjos.22_?igsh=OHkzbnhjcG91bDBr"><img src="https://img.shields.io/badge/Instagram-E4405F?style=for-the-badge&logo=instagram&logoColor=white" alt="Instagram"></a>
</p>

**TermAI** é um _agente de IA local_ construído para rodar em celulares Android via [Termux](https://termux.dev). Funciona como um assistente de terminal com ferramentas de shell, compactação de contexto, memória de longo prazo, sessões persistentes, permissões de comandos, streaming em tempo real, suporte a múltiplos provedores, hooks extensíveis e sistema de skills.

Um agente que roda no bolso — sem daemon permanente, sem servidor próprio — conectando-se a provedores de IA sob demanda.

---

## Highlights

- **Multi-Provedor** — suporte a OpenRouter, Google, NVIDIA, Cloudflare, mimo, opencode, Cline, Gitlawb (OpenGateway), Kilo Gateway e provedores customizados. Use o modelo que preferir.
- **Interface TUI** — terminal interativo completo com streaming em tempo real, exibição de raciocínio do modelo e display de ferramentas em execução.
- **Ferramentas de Shell** — execução de comandos bash, leitura/escrita/edição de arquivos, busca no sistema e cálculos. O agente interage diretamente com o terminal quando necessário.
- **Web Tools** — pesquisa na web via DuckDuckGo, Google Grounding, Tavily e fetch direto de URLs. O agente navega a internet quando precisa.
- **Memória de Longo Prazo** — sistema de flush/arquivamento de contexto em arquivos Markdown. Totalmente opcional — quando ativado, o agente salva contexto periodicamente, mas gasta tokens extras por rodada.
- **Compactação de Contexto** — quando o contexto fica grande demais, o TermAI resume automaticamente o histórico preservando o que importa, sem perder o fio da meada.
- **Sessões Persistentes** — conversas são salvas automaticamente. Feche o app e volte depois — o contexto continua de onde parou.
- **Políticas de Permissão** — o agente aplica políticas de aprovação baseadas em segurança e risco do comando. Comandos de baixo risco rodam direto; comandos de alto risco pedem aprovação. Você decide o que o agente pode fazer.
- **Hooks e Skills** — extensível com scripts do usuário e módulos carregáveis para testes, debugging e planejamento.
- **Conectores (MCP)** — item de menu em `TermAI config` (TUI e CLI) ainda é **stub** (“Em desenvolvimento”). Streamable HTTP foi validado; OAuth e cliente MCP nativo estão pendentes. Não há runtime de MCP no código atual.
- **Canal Telegram** — entry point `agente_telegram.lua` + módulo `channels/telegram` existem no tree. Ainda não há subcomando CLI dedicado nem cobertura em `tests/`; o canal não aparece no banner/`help` (Issue #57).
- **Mais atualizações virão** — o TermAI está em desenvolvimento ativo. Novas funcionalidades, melhorias de performance e novos provedores serão adicionados continuamente.

---

## Instalação (recomendado)

O caminho oficial de instalação usa o script `install.sh`, que cria o comando global `TermAI` no PATH do Termux (wrapper com loop de restart).

```bash
# 1. Instalar Termux (F-Droid ou termux.dev) e dependências base
pkg install -y lua54 git curl

# 2. Clonar o repositório
git clone https://github.com/Sjos0/TermAI.git ~/TermAI
cd ~/TermAI

# 3. Rodar o instalador (idempotente)
bash install.sh
```

Após a instalação, o binário `TermAI` fica disponível de qualquer pasta:

```bash
TermAI          # menu de comandos
TermAI tui      # inicia o agente interativo
TermAI status   # status do sistema
TermAI help     # ajuda detalhada
```

O instalador:

- Instala `lua54`, `git` e `curl` se ainda não estiverem presentes.
- Clona ou atualiza o repositório em `$HOME/TermAI`.
- Escreve o wrapper `$PREFIX/bin/TermAI` que invoca `lua5.4 $HOME/TermAI/main.lua` com loop de restart (exit code 123).
- O pacote Termux é `lua54`; o binário é `lua5.4`.

### Uso sem instalador (legado / desenvolvimento)

```bash
cd ~/TermAI
lua5.4 main.lua tui
```

---

## Comandos CLI

Após a instalação, o entry point `main.lua` despacha subcomandos:

| Comando | Descrição |
|---------|----------|
| `TermAI` | Exibe o menu de comandos disponíveis |
| `TermAI tui` | Inicia o agente interativo (TUI) |
| `TermAI config` | Configurações (timeout, hooks, modelos…) |
| `TermAI models` | Gerenciar provedores e modelos de IA |
| `TermAI status` | Status da sessão ativa |
| `TermAI update` | Atualiza o TermAI a partir do GitHub (origin/main) |
| `TermAI skills` | Instala e gerencia skills do agente |
| `TermAI npx` | Alias de `skills` (instalador de skills) |
| `TermAI restart` | Solicita restart do processo TermAI |
| `TermAI help` | Ajuda detalhada |

Exemplos de uso de `models`:

```bash
TermAI models add-provider
TermAI models list
TermAI models set
```

---

## Estrutura

```
TermAI/
├── agent/              # Loop principal, API, compactação, flush
│   └── hooks/          # Sistema de eventos (engine, permissions, patterns)
├── providers/          # Provedores de chat e busca (openrouter, google, cline…)
├── tools/              # Ferramentas e execução de comandos
├── ui/                 # Interface TUI, streaming, renderização
├── session/            # Persistência de sessões (JSONL)
├── config/             # Configuração e migração
├── commands/           # Comandos do usuário (/compact, /config, etc.) e CLI
├── memoryflush/        # Memória de longo prazo (flush/arquivamento)
├── tests/              # Specs e fixtures locais (sem runner CI formal; executar com lua/busted conforme cada spec)
├── channels/           # Canais alternativos (ex.: telegram)
├── .claude/ .grok/ .jules/  # Prompts/personas de agentes externos (não são runtime)
├── install.sh          # Instalador: cria o comando global TermAI
├── main.lua            # Entry point CLI (despacha tui, models, config…)
├── agente_telegram.lua # Entry point do canal Telegram
└── config.lua          # Fachada de configuração
```

---

## Security Model

O TermAI aplica políticas de aprovação baseadas em segurança e risco do comando:

- Comandos de **baixo risco** (echo, cat, find, grep, lua) → aprovados automaticamente
- Comandos de **alto risco** (rm, mv, dd) → requerem aprovação explícita
- Outros comandos → o sistema avalia o contexto e histórico de aprovações
- Validações de segurança incluem detecção de command injection, proteção contra path traversal e parsing de heredocs
- `curl` disponível para chamadas HTTP quando necessário

---

## Operator Quick Refs

### Comandos de sessão (dentro da TUI)

Lista canônica em `commands/available.lua` (e tratada pelo router em `agent/main_loop/commands_router/`):

- `/models` — gerenciar modelos de IA
- `/config` — configurações (Memory Flush e mais)
- `/commands` — listar comandos disponíveis
- `/new` — iniciar uma nova sessão/conversa
- `/reset` — limpar a conversa atual (mantém o ID da sessão)
- `/session` — listar sessões; `/session <id>` para trocar
- `/clear` — deletar a conversa atual e migrar para outra sessão
- `/compact` — compacção manual (com foco opcional: `/compact foque em X`)
- `/status` — ver status do TermAI
- `/restart` — reiniciar a TUI
- `/help` — mostrar ajuda dos slash commands
- `/sair` — encerrar o TermAI

### Comandos de linha de comando (pós-instalação)

- `TermAI tui` — inicia o agente
- `TermAI models add-provider` — configura provedor
- `TermAI update` — atualiza a partir do GitHub
- `TermAI help` — ajuda detalhada

---

## Stack Técnica

| Componente | Tecnologia |
|---|---|
| Linguagem | Lua 5.4 (PUC-Rio) |
| Runtime | Termux no Android (Linux ARM) |
| HTTP | curl via shell (streaming SSE) |
| Persistência | JSONL + Lua tables |
| Dependências Lua | Nenhuma externa (todas internas) |
| Runtime mínimo | Termux + Lua 5.4 + curl + shell |

---

## Community

- [GitHub Issues](https://github.com/Sjos0/TermAI/issues) — bugs e feature requests
- [Instagram](https://www.instagram.com/sjos.22_?igsh=OHkzbnhjcG91bDBr) — @[sjos.22_](https://www.instagram.com/sjos.22_?igsh=OHkzbnhjcG91bDBr)

---

## Author

Samuel — [@Sjos0](https://github.com/Sjos0)

Ameno 🦇 — co-autor e assistente de desenvolvimento

Desenvolvido com assistência de IA no Termux.
