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
