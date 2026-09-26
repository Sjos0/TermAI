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

## Instalacao

PLACEHOLDER_REST
