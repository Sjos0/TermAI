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

- **Multi-Provedor** — suporte a OpenRouter, Google, NVIDIA, Cloudflare, mimo, opencode e provedores customizados. Use o modelo que preferir.
- **Interface TUI** — terminal interativo completo com streaming em tempo real, exibição de raciocínio do modelo e display de ferramentas em execução.
- **Ferramentas de Shell** — execução de comandos bash, leitura/escrita/edição de arquivos, busca no sistema e cálculos. O agente interage diretamente com o terminal quando necessário.
- **Web Tools** — pesquisa na web via DuckDuckGo, Google Grounding, Tavily e fetch direto de URLs. O agente navega a internet quando precisa.
- **Memória de Longo Prazo** — sistema de flush/arquivamento de contexto em arquivos Markdown. Totalmente opcional — quando ativado, o agente salva contexto periodicamente, mas gasta tokens extras por rodada.
- **Compactação de Contexto** — quando o contexto fica grande demais, o TermAI resume automaticamente o histórico preservando o que importa, sem perder o fio da meada.
- **Sessões Persistentes** — conversas são salvas automaticamente. Feche o app e volte depois — o contexto continua de onde parou.
- **Políticas de Permissão** — o agente aplica políticas de aprovação baseadas em segurança e risco do comando. Comandos de baixo risco rodam direto; comandos de alto risco pedem aprovação. Você decide o que o agente pode fazer.
- **Hooks e Skills** — extensível com scripts do usuário e módulos carregáveis para testes, debugging e planejamento.
- **Mais atualizações virão** — o TermAI está em desenvolvimento ativo. Novas funcionalidades, melhorias de performance e novos provedores serão adicionados continuamente.
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
├── memoryflush/        # Memória de longo prazo (flush/arquivamento)
├── hooks/              # Sistema de eventos
├── tests/              # Testes automatizados
├── main.lua            # Entry point
└── config.lua          # Fachada de configuração
```

---

## Security Model

O Termai aplica políticas de aprovação baseadas em segurança e risco do comando:

- Comandos de **baixo risco** (echo, cat, find, grep, lua) → aprovados automaticamente
- Comandos de **alto risco** (rm, mv, dd) → requerem aprovação explícita
- Outros comandos → o sistema avalia o contexto e histórico de aprovações
- Validações de segurança incluem detecção de command injection, proteção contra path traversal e parsing de heredocs
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
