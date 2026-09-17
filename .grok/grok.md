# Grok — Contribution Log

Registro de contribuições do Grok (xAI) ao projeto TermAI.

---

## 2026-08-06 - [Diagnóstico: Cache parcial de grafo é falsa otimização]

**Contexto:** Continuação da sessão de permissões Exec + GraphRAG. Samuel anexou a Spec completa criada pelo Ameno.
**Diagnóstico confirmado:** cache parcial (tags/snippets) não resolve ~25s de boot.
**Ação:** PR #21 com cache de grafo completo + incremental.

**Author:** Grok 4.5 (xAI)

---

## 2026-08-06 - [PR #21 v2.1 — Fixes do review do Ameno + UI de permissão]

**Fixes Ameno (3 críticos):** cache sem content, zero stat no hot path, invalidate só RAM, arestas bidirecionais, TMPDIR.
**Fixes UI:** status limpo, colapso completo, suggest sem lixo, deny orientativo.

**Author:** Grok 4.5 (xAI)

---

## 2026-08-06 - [PR #21 v3.2 — Regressão dirty flag (auditoria final Ameno)]

**Regressão:** `invalidate_cache()` só limpava RAM; hot path confiava no disco quando `file_count` igual → índice stale após Edit/Write em arquivo de memória.

**Fix:** `_cache.dirty = true` em `invalidate_cache()`. Hot path só confia no disco se `dirty == false`. Após recheck de mtimes, limpa dirty. Callers (editor/write/todo) não precisam mudar.

**Author:** Grok 4.5 (xAI)
**Status:** Mergeado via PR #21.

---

## 2026-08-07 a 2026-08-09 - [PR #24: Alternate Screen Modal — resolve bug Termux scroll]

**Período:** Criada 07/08, atualizada até 09/08, mergeada 09/08.
**Contexto:** A PR #23 (cursor save/restore) falhava no Termux quando o diálogo era longo o bastante para rolar a tela — a posição salva se perdia e o box ficava preso.
**Evolução incremental (3 versões):**
1. **v1/v2** — Contar `\n` + `ESC[1A` → quebrava com wrap visual
2. **v3 (PR #23)** — `ESC[s` save cursor + `ESC[u` + `ESC[0J` → falha no Termux scroll
3. **v5 (PR #24)** — Alternate screen buffer (`ESC[?1049h/l`) → correto, terminal cuida de scroll/wrap

**Fix:**
- `enter_modal_screen()` — DECSET 1049 (tela alternativa) + clear + home
- `leave_modal_screen()` — DECRST 1049 (volta pra tela principal)
- `xpcall` garante `leave_modal_screen()` mesmo em erro
- Teste novo: `permissions_ui_modal_spec.lua` (162 linhas, 55 casos)
- Removido: `ESC[1A`, `ESC[2K`, contagem de linhas, `collapse_and_resolve`

**Validação (no Termux real):**
- `luac -p`: ✅ 2/2
- `permissions_ui_modal_spec`: 52/55 (3 falhas no `<Enter>` — timing do mock, não bug real)
- `bash_patterns_bug`: 64/64 ✅
- `graph_cache_full_spec`: 10/10 ✅
- `fuzzy_match_pr4`: ✅
- `thinking_spinner`: 15/15 ✅
- **Zero regressões**

**Author:** Grok 4.5 (xAI)
**Status:** Mergeado (commit `8c5c820`). Branch deletada.

---

## 2026-08-09 - [Ajuste de espaçamento: linha em branco entre status e Exec]

**Contexto:** Samuel reportou que o status `✅ Permitido uma vez` **Contexto:** Samuel reportou que o status ficava colado no header do Exec. Exec (...)`.
**Fix:** `"\n"` → `"\n\n"` no `io.write` do status (1 caractere).
**Arquivo:** `tools/exec/permissions_ui.lua`
**Author:** Grok 4.5 (xAI) + Ameno (edição local)
**Status:** Aplicado localmente. Aguardando confirmação visual do Samuel.

---

## 2026-09-10 - [PR #40: facade agent/loop + fix last_reasoning no cancel JSON]

**Contexto:** Issue #29 — monólito `agent/loop.lua` (187 linhas) concentrava loop ReAct e protocolo.
**Implementação:** fachada `M.rodar` + `system_messages`, `response_utils`, `json_path`, `xml_path` (branch `refactor/29-agent-loop-facade`).
**Review Caçador:** divergência residual — cancel JSON hardcodava `last_reasoning = ""` em vez de propagar o outer da fachada.
**Fix:** `json_path.handle` recebe e propaga `last_reasoning` no return de cancel (`3de8a67`); FLUSH_DONE continua zerando.
**Testes:** trava em `tests/loop_units_spec.lua` — cancel com outer vazio e com outer **não-vazio** (guarda contra regressão do hardcode).

**Author:** Grok (xAI) — Agente Implementador
**Status:** PR #40 aberta; correção e teste forte na mesma branch.

---

## 2026-09-14 - [PR: fix README DOC-GAP #35 + VERSION 1.14.09.2026]

**Contexto:** Issue #35 — README ainda documentava apenas o fluxo legado (`lua5.4 main.lua`) e omitia `install.sh`, o comando global `TermAI` e os subcomandos CLI (`tui`, `models`, `config`, `update`, etc.).

**O que foi feito:**
- Reescrita da seção de instalação: caminho recomendado via `install.sh` + wrapper `$PREFIX/bin/TermAI`.
- Documentação dos comandos CLI disponíveis pós-instalação.
- Atualização da árvore de estrutura para incluir `install.sh` e esclarecer o papel de `main.lua`.
- Operator Quick Refs agora distingue comandos de sessão (TUI) e comandos de linha de comando.
- Bump de VERSION de `1.2.0` → `1.14.09.2026` (formato data embutida no dia da entrega).

**Decisão de versão:** escolhido `1.14.09.2026` (1. + dia.mês.ano) para manter prefixo semântico leve e deixar a data de release explícita, alinhado à sugestão do solicitante (ajustando mês para setembro/2026).

**Author:** Grok (xAI) — Agente Implementador
**Status:** Branch `fix/35-readme-install-cli`; PR a abrir.

---

## 2026-09-15 - [PR: fix latex false positives #36 + VERSION 1.15.09.2026]

**Contexto:** Issue #36 — `apply_latex` substituía substrings de comandos LaTeX em paths (`path\to\file` → `path→\file`), drives Windows (`C:\times\data`) e tratava `$100` como math mode.

**O que foi feito:**
- Passagem standalone: boundary à **esquerda** além da direita — não substitui se o caractere anterior for alfanumérico, `\` ou `:` (paths Unix/Windows).
- Passagem inline `$...$`: heurística de moeda — se o conteúdo (após espaços) começa com dígito e não contém `\`, o par `$...$` é preservado.
- Pattern de display math `$$...$$` corrigido para `%$%$(.-)%$%$` (estava com escape incorreto).
- Suite de regressão nova: `tests/latex_false_positives_spec.lua` (paths, moeda, guard de letra, math legítimo, bordas).
- Bump VERSION `1.14.09.2026` → `1.15.09.2026`.

**Decisões de design:**
- Política de moeda: preservar `$` + dígito sem `\` (ex.: `$100`). Math com `\` dentro continua convertido.
- Boundary esquerda deliberadamente inclui `:` para cobrir `C:\...` sem heurística de drive letter.
- Escopo limitado ao bug reportado; sem refatoração arquitetural do processador (candidata a issue futura).

**Author:** Grok (xAI) — Agente Implementador
**Status:** Branch `fix/36-latex-false-positives`; PR a abrir.

---

## 2026-09-16 - [PR: desativação de tools por agente #32 + VERSION 1.16.09.2026]

**Contexto:** Issue #32 — permitir desativar (e reativar) tools de forma persistente e por agente, de modo que tools desativadas não entrem no schema enviado ao modelo.

**O que foi feito:**
- `tools.get_schema(disabled)` / `tools.get_docs(disabled)` com filtro opcional (set ou array); ordem estável preservada; nil se zero tools restarem.
- `agent/context.lua`: resolve agente ativo por id, popula `ctx.disabled_tools` (set) e `ctx.agent_id` — sem hardcode `"main"`.
- `agent/api/payload.lua`: passa `ctx.disabled_tools` para `get_schema`; `ctx.no_tools` continua soberano (compactação).
- Defesa em profundidade em `tools.call` / `tools.call_structured` (erro claro se path legado chamar tool desativada).
- Menu TUI `commands/config/menus/tools.lua` e CLI `commands/config_cli/menus/tools.lua`: lista do registry, toggle individual, desativar todas, reativar todas; persiste em `agents.list[].disabled_tools`.
- Registro da opção 8 nos menus principais de config (TUI e CLI).
- Bump VERSION `1.15.09.2026` → `1.16.09.2026`.

**Decisões de design:**
- Filtro centralizado na fachada `tools` (parâmetro explícito) — não acopla tools a ctx global.
- Persistência no entry do agente (não em defaults nem em sessão).
- Permissões (ask/block/always) intocadas e ortogonais.
- Multi-agent-ready: resolve por id do agente ativo.

**Author:** Grok (xAI) — Agente Implementador
**Status:** Branch `feature/32-disable-tools-per-agent`; PR a abrir.

---
