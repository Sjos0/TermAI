# TermAI

**Engenharia de Harness para Agentes Inteligentes**

TermAI é um agente autônomo open-source projetado para rodar diretamente em celulares Android via [Termux](https://termux.dev). Diferente de soluções que dependem de servidores ou desktops, o TermAI foi construído do zero para operar em hardware limitado — oferecendo uma experiência completa de agente de IA sem precisar de nada além do seu celular.

---

## O que é o TermAI?

TermAI é um **harness de engenharia** — uma infraestrutura completa que permite a um modelo de linguagem (LLM) interagir com o mundo real: executar comandos, editar arquivos, navegar na web, gerenciar memória de longo prazo e manter conversas coesas ao longo de sessões inteiras.

Ele não é apenas um chatbot. É um **sistema operacional para agentes** que roda no bolso.

---

## Por que existe?

Modelos de linguagem têm janelas de contexto limitadas. Sessões longas estouram essas janelas. A maioria das soluções assume um desktop com recursos abundantes. O TermAI foi criado para resolver esse problema em **celulares** — onde memória, CPU e conexão são escassos.

---

## Características

Arquitetura similar aos harnesses de agentes de mercado (OpenClaw, Claude Code, Aider), adaptada para rodar em hardware mínimo: compactação de contexto, Memory Flush, sessões persistentes, permissões granulares de comandos, streaming em tempo real, suporte a múltiplos provedores, hooks extensíveis e sistema de skills. Tudo otimizado para Termux no Android.

---

## Stack Técnica

- **Linguagem:** Lua 5.4 (PUC-Rio)
- **Runtime:** Termux no Android (Linux ARM)
- **API HTTP:** curl via shell (streaming SSE)
- **Persistência:** JSONL + Lua tables
- **Dependências:** Zero (todas as bibliotecas são internas)

---

## Estrutura

```
TermAI/
├── agent/              # Loop principal, API, compactação, flush
├── tools/              # Definição e execução de ferramentas
├── ui/                 # Interface TUI, streaming, renderização
├── session/            # Persistência de sessões (JSONL)
├── config/             # Configuração e migração
├── commands/           # Comandos do usuário (/compact, /config, etc.)
├── memoryflush/        # Sistema de Memory Flush (GraphRAG)
├── hooks/              # Sistema de eventos (PreToolUse, PostToolUse)
├── tests/              # Testes automatizados
├── main.lua            # Entry point
└── config.lua          # Fachada de configuração
```

---

## Início Rápido

```bash
# Instalar Termux
# https://termux.dev

# Clonar
git clone https://github.com/Sjos0/TermAI.git ~/TermAI
cd ~/TermAI

# Executar
lua main.lua
```

---

## Licença

Open Source — use, modifique e distribua livremente.

---

## Autor

Samuel — [@Sjos0](https://github.com/Sjos0)

Desenvolvido com assistência de IA no Termux. 🦇
