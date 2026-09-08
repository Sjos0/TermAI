-- providers/google_grounding/formatter.lua — Montagem do texto final (queries + fontes + markdown).
local M = {}

--- Formata a saída de sucesso do Search Grounding.
-- @param query string Query original do usuário
-- @param response_text string Texto extraído da resposta
-- @param sources table Lista de {url, title, ...}
-- @param queries table Lista de queries executadas
-- @return string Texto formatado para o usuário
function M.format_result(query, response_text, sources, queries)
  local out = { "🔍 **Resultado:** \"" .. query .. "\"\n" }

  -- Adicionar queries executadas (se houver)
  if #queries > 0 then
    out[#out + 1] = "🔎 *Queries:* " .. table.concat(queries, ", ") .. "\n"
  end

  out[#out + 1] = response_text

  -- Adicionar fontes
  if #sources > 0 then
    out[#out + 1] = "\n📎 **Fontes:**"
    local seen = {}
    local idx = 0
    for _, src in ipairs(sources) do
      if not seen[src.url] then
        idx = idx + 1
        seen[src.url] = true
        out[#out + 1] = idx .. ". " .. src.title .. " — " .. src.url
      end
    end
  end

  return table.concat(out, "\n")
end

return M
