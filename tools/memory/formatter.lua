-- formatter.lua — Formatação dos resultados ranqueados em string de saída para o agente.
local M = {}

local MAX_RESULTS  = 3
local MAX_SNIPPETS = 2

local function format_results(sorted, query, files, tokens)
  if #sorted == 0 then
    return "🔍 Nenhuma memória encontrada para: \"" .. query .. "\"\n"
      .. "💡 Tente termos mais genéricos ou verifique as tags nos arquivos .md."
  end

  -- ── Formatação da resposta ────────────────────────────────────────────────
  local sep    = string.rep("─", 44)
  local result = "🧠 **Memórias relevantes para:** \"" .. query .. "\"\n"
              .. "📊 " .. #sorted .. " arquivo(s) | Grafo: "
              .. #files .. " nós | " .. #tokens .. " token(s) buscado(s)\n"
              .. sep .. "\n"

  for i = 1, math.min(MAX_RESULTS, #sorted) do
    local item = sorted[i]
    result = result
          .. "\n📅 **" .. item.data.date .. "**"
          .. "  (relevância: " .. item.data.score .. ")\n"

    -- Deduplica snippets
    local seen_snips = {}
    local shown      = 0
    for _, snip in ipairs(item.data.snippets) do
      local key = snip:sub(1, 60)
      if not seen_snips[key] and shown < MAX_SNIPPETS then
        seen_snips[key] = true
        shown = shown + 1
        result = result .. snip .. "\n"
      end
    end
    result = result .. sep .. "\n"
  end

  if #sorted > MAX_RESULTS then
    result = result .. "… e mais " .. (#sorted - MAX_RESULTS)
           .. " arquivo(s) com relevância menor.\n"
  end

  return result
end

M.MAX_RESULTS    = MAX_RESULTS
M.MAX_SNIPPETS   = MAX_SNIPPETS
M.format_results = format_results
return M
