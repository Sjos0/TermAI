# Grok — Contribution Log

Registro de contribuições do Grok (xAI) ao projeto TermAI.

---

## 2026-08-06 - [Diagnóstico: Cache parcial de grafo é falsa otimização]

**Contexto:** Continuação da sessão de permissões Exec + GraphRAG. Samuel anexou a Spec completa criada pelo Ameno.
**Diagnóstico confirmado (contra a sugestão anterior de só trocar size→mtime):**
- O cache parcial (tags/snippets) **não resolve** o boot de ~25s.
- Benchmark da Spec: JSON decode 1.46s + montagem do grafo ainda lê os 83 arquivos e reconstrói nós/arestas/índice → 23.6s.
- Causa raiz: o gargalo real é a reconstrução da estrutura completa, não só extract_tags/get_snippet.
- Solução correta = cache do **grafo inteiro** + atualização incremental por mtime (conforme Spec FR-001 a FR-007).

**Ação:** Implementação completa da Spec (v2 do graph_cache).

**Files Modified / Created:**
- `tools/memory/graph_cache.lua` — reescrito: salva grafo completo + file_hashes (mtime), version=2
- `tools/memory/graph_builder.lua` — adiciona `build_graph_full`, `update_graph_node`, `remove_graph_node`, `get_mtime`
- `tools/memory.lua` — orquestrador incremental (caminho quente vs frio)
- `tests/graph_cache_full_spec.lua` — testes AC-001..AC-006 isolados
- `.grok/grok.md`: primeiras entradas do Grok

**Learning:** Medir antes de otimizar. Um cache que salva o dado intermediário errado dá a ilusão de progresso (e ainda adiciona o custo do JSON decode).

**Author:** Grok 4.5 (xAI)
**Status:** Implementado. Aguardando review do Ameno na PR.

---

## 2026-08-06 - [Permissões Exec: status line limpa + deny devolve turno]

**Contexto:** Continuação dos bugs de UI de permissão reportados pelo Samuel.
**Pedidos:**
1. Após decisão, mostrar **só** "✅ Permitido uma vez / sempre" (sem o comando).
2. Negação/cancel → reason orientativa para o agente devolver o input ao usuário.
3. Linha de status some após a tool terminar.
4. Ainda apareciam solicitações com fragmentos `/*` (lacuna na description).

**Nota:** Patch de permissões ficou documentado no prompt anterior para o Ameno; esta entrada registra a intenção e o diagnóstico. Implementação de memória priorizada por causa da Spec anexada.

**Author:** Grok 4.5 (xAI)

---
