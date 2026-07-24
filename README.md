# 🦇 TermAI — Harness de Engenharia para Agentes Inteligentes

<p align="center">
  <a href="https://github.com/Sjos0/TermAI/actions"><img src="https://img.shields.io/github/actions/workflow/status/Sjos0/TermAI/main?style=for-the-badge&label=CI" alt="CI status"></a>
  <a href="https://github.com/Sjos0/TermAI/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge" alt="MIT License"></a>
  <a href="https://github.com/Sjos0/TermAI"><img src="https://img.shields.io/github/stars/Sjos0/TermAI?style=for-the-badge" alt="GitHub stars"></a>
  <a href="https://www.instagram.com/sjos.22_?igsh=OHkzbnhjcG91bDBr"><img src="https://img.shields.io/badge/Instagram-E4405F?style=for-the-badge&logo=instagram&logoColor=white" alt="Instagram"></a>
</p>

**TermAI** é um _harness de engenharia_ para agentes inteligentes, construído do zero para rodar em celulares Android via [Termux](https://termux.dev). Arquitetura similar aos harnesses de mercado (OpenClaw, Claude Code, Aider), adaptada para hardware mínimo: compactação de contexto, Memory Flush, sessões persistentes, permissões granulares de comandos, streaming em tempo real, suporte a múltiplos provedores, hooks extensíveis e sistema de skills.

Se você quer um agente de IA que roda no bolso, é sempre ativo e funciona sem servidor — este é o projeto.

---

## Highlights

- **[Compactação de Contexto v7](#)** — corte por tokens, merge iterativo, split-turn, poda mecânica, anti-thrashing
- **[Memory Flush](#)** — arquivamento periódico com GraphRAG para memória de longo prazo
- **[Sessões Persistentes](#)** — JSONL atômico com restore automático
- **[Permissões Granulares](#)** — auto-approve para comandos seguros, aprovação manual para perigosos
- **[Streaming em Tempo Real](#)** — respostas aparecem na TUI enquanto são geradas
- **[Multi-Provedor](#)** — OpenRouter, Google, Anthropic e provedores customizados
- **[Hooks Extensíveis](#)** — PreToolUse, PostToolUse, OnMemoryFlush, scripts do usuário
- **[Skills](#)** — módulos carregáveis para testes, debugging, planejamento

---

## Install (recommended)

Runtime: **Lua 5.4+** via [Termux](https://termux.dev) no Android.

```bash
# Instalar Termux (F-Droid ou termux.dev)
pkg install lua5.4 git

# Clonar
git clone https://github.com/Sjos0/TermAI.git ~/TermAI
cd ~/TermAI

# Executar
lua5.4 main.lua
```

---

## Quick Start (TL;DR)

```bash
# Clone + execute em 2 comandos
git clone https://github.com/Sjos0/TermAI.git ~/TermAI && lua5.4 ~/TermAI/main.lua
```

Configure seu modelo em `~/.TermAI/config.json` com provider e API key.
Veja `config/migrate.lua` para exemplos de configuração.

---

## Estrutura

```
TermAI/
├── agent/              # Loop principal, API, compactação, flush
├── tools/              # Ferramentas e execução de comandos
├── ui/                 # Interface TUI, streaming, renderização
├── session/            # Persistência de sessões (JSONL)
├── config/             # Configuração e migração
├── commands/           # Comandos do usuário (/compact, /config, etc.)
├── memoryflush/        # Memory Flush (GraphRAG)
├── hooks/              # Sistema de eventos
├── tests/              # Testes automatizados
├── main.lua            # Entry point
└── config.lua          # Fachada de configuração
```

---

## Security Model

- Comandos **seguros** (echo, cat, find, grep, lua) → auto-approve sem dialog
- Comandos **perigosos** (rm, mv, dd) → SEMPRE pede permissão
- Outros comandos → pede permissão uma vez, padrão pode ser salvo
- Heredocs (`<<`) → reconhecidos e ignorados pelo parser de segurança
- `curl` disponível para chamadas HTTP quando necessário

---

## Operator Quick Refs

- `/compact` — compactação manual (com foco opcional: `/compact foque em X`)
- `/config` — reconfiguração de modelos
- `/models` — seleção de modelo
- `/clear` — limpar contexto da sessão
- `/status` — ver status do TermAI

---

## Stack Técnica

| Componente | Tecnologia |
|---|---|
| Linguagem | Lua 5.4 (PUC-Rio) |
| Runtime | Termux no Android (Linux ARM) |
| HTTP | curl via shell (streaming SSE) |
| Persistência | JSONL + Lua tables |
| Dependências | Zero (tudo interno) |

---

## Community

- [GitHub Issues](https://github.com/Sjos0/TermAI/issues) — bugs e feature requests
- [Instagram](https://www.instagram.com/sjos.22_?igsh=OHkzbnhjcG91bDBr) — @[sjos.22_](https://www.instagram.com/sjos.22_?igsh=OHkzbnhjcG91bDBr)

---

## Author

Samuel — [@Sjos0](https://github.com/Sjos0)

Desenvolvido com assistência de IA no Termux. 🦇
