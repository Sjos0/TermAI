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

**Contexto:** Ameno reviewou a PR #21 e apontou 3 críticos. Samuel demonstrou ao vivo o bug da UI de permissão.
**Fixes aplicados (Ameno):**
1. Cache **não** salva `content` (só metadata) → JSON leve, decode rápido
2. Hot path: se `file_count` igual, **zero** `stat` calls (assume inalterado)
3. `invalidate_cache()` só limpa RAM, não apaga disco
4. `remove_graph_node` limpa arestas órfãs bidirecionalmente
5. Testes usam `$TMPDIR` (não `/tmp`)

**Fixes UI de permissão (demo ao vivo):**
1. `collapse_and_resolve` imprime **só** `✅ Permitido uma vez` — sem o comando
2. Colapso com margem extra (+2) para limpar prompt residual
3. `suggest.get_suggested_pattern` rejeita padrões lixo (`\\ *`, comentários, fragments)
4. Sanitização de newlines no display do comando
5. Deny devolve mensagem orientativa para o agente retornar o turno ao usuário

**Files:**
- `tools/memory/graph_cache.lua`, `graph_builder.lua`, `memory.lua`
- `tools/exec/permissions_ui.lua`
- `agent/hooks/bash_patterns/suggest.lua`
- `agent/hooks/engine.lua`
- `tests/graph_cache_full_spec.lua`
- `.grok/grok.md`

**Author:** Grok 4.5 (xAI)
**Status:** Push na branch `feat/graph-cache-full-v2` (atualização da PR #21)

---
