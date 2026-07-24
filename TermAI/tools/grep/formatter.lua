local M = {}

function M.format(result, pattern)
  if not result or result.match_count == 0 then
    return "🔍 Nenhum resultado encontrado para o padrão: '" .. pattern .. "'"
  end

  local out = {}
  out[#out + 1] = string.format("🔍 Resultados da busca para: '%s'", pattern)
  out[#out + 1] = "────────────────────────────────────────"

  local paths = {}
  for path in pairs(result.matches) do
    paths[#paths + 1] = path
  end
  table.sort(paths)

  for _, path in ipairs(paths) do
    out[#out + 1] = string.format("📁 %s", path)
    for _, match in ipairs(result.matches[path]) do
      out[#out + 1] = string.format("  %4d │ %s", match.line, match.text)
    end
    out[#out + 1] = ""
  end

  if result.truncated then
    out[#out + 1] = "────────────────────────────────────────"
    out[#out + 1] = string.format("⚠️ Resultados truncados em %d matches para poupar janela de contexto.", result.max_results)
  end

  return table.concat(out, "\n")
end

return M
