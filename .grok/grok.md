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
**Status:** Aguardando re-auditoria do Ameno. Sem merge até aprovação.

---
