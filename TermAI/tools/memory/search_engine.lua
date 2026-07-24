-- search_engine.lua — Motor de busca: scoring por tags e keyword, ranking e saída.
-- Fase 1: índice invertido + expansão de grafo. Fase 2: fallback por keyword.
local tokenizer = require("tools.memory.tokenizer")
local formatter = require("tools.memory.formatter")
local M = {}

local SCORE = {
  TAG_EXACT    = 10,  -- tag indexada bate exatamente com o token
  TAG_PARTIAL  = 5,   -- token está contido no nome da tag
  GRAPH_HOP    = 3,   -- arquivo alcançado via aresta do grafo (co-ocorrência)
  KEYWORD_BODY = 1,   -- palavra-chave encontrada no corpo do texto
}

local function search(query, graph, files)
  local tokens = tokenizer.tokenize(query)
  if #tokens == 0 then
    return "❌ memory_search: query inválida após normalização."
  end

  -- hits: path → {score, snippets[], date, file}
  local hits = {}

  local function ensure_hit(path, node_or_entry)
    if not hits[path] then
      hits[path] = {
        score    = 0,
        snippets = {},
        date     = node_or_entry.date,
        file     = node_or_entry.file,
      }
    end
  end

  -- ── Fase 1: busca por tags no índice invertido ────────────────────────────
  for _, token in ipairs(tokens) do

    -- Match exato de tag
    if graph.index[token] then
      for _, entry in ipairs(graph.index[token]) do
        ensure_hit(entry.path, entry)
        hits[entry.path].score = hits[entry.path].score + SCORE.TAG_EXACT
        hits[entry.path].snippets[#hits[entry.path].snippets + 1] = entry.snippet
      end

      -- Expansão pelo grafo: segue co-ocorrências (1 hop)
      if graph.edges[token] then
        for _, related_tag in ipairs(graph.edges[token]) do
          if graph.index[related_tag] then
            for _, entry in ipairs(graph.index[related_tag]) do
              ensure_hit(entry.path, entry)
              hits[entry.path].score = hits[entry.path].score + SCORE.GRAPH_HOP
            end
          end
        end
      end
    end

    -- Match parcial de tag (token contido no nome da tag)
    for tag, entries in pairs(graph.index) do
      if tag ~= token and tag:find(token, 1, true) then
        for _, entry in ipairs(entries) do
          ensure_hit(entry.path, entry)
          hits[entry.path].score = hits[entry.path].score + SCORE.TAG_PARTIAL
          hits[entry.path].snippets[#hits[entry.path].snippets + 1] = entry.snippet
        end
      end
    end
  end

  -- ── Fase 2: fallback por keyword no corpo do texto ────────────────────────
  if next(hits) == nil then
    for filepath, node in pairs(graph.nodes) do
      local body = node.content:lower()
      for _, token in ipairs(tokens) do
        local pos = body:find(token, 1, true)
        if pos then
          ensure_hit(filepath, node)
          hits[filepath].score = hits[filepath].score + SCORE.KEYWORD_BODY
          -- Snippet ao redor da keyword
          local s = math.max(1, pos - 80)
          local e = math.min(#node.content, pos + 220)
          local snip = node.content:sub(s, e)
          if s > 1 then snip = "…" .. snip end
          if e < #node.content then snip = snip .. "…" end
          hits[filepath].snippets[#hits[filepath].snippets + 1] = snip
        end
      end
    end
  end

  -- ── Ranking ───────────────────────────────────────────────────────────────
  local sorted = {}
  for path, data in pairs(hits) do
    sorted[#sorted + 1] = { path = path, data = data }
  end
  table.sort(sorted, function(a, b)
    -- Primário: score; Secundário: data mais recente
    if a.data.score ~= b.data.score then
      return a.data.score > b.data.score
    end
    return (a.data.date or "") > (b.data.date or "")
  end)

  return formatter.format_results(sorted, query, files, tokens)
end

M.SCORE  = SCORE
M.search = search
return M
