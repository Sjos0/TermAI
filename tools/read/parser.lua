local M = {}

-- Analisa o argumento da ferramenta Read e retorna uma tabela com:
--   path  — caminho do arquivo (não expandido)
--   mode  — "full" | "range"
--   ls    — linha inicial   (somente modo range)
--   le    — linha final     (somente modo range)
--
-- Correção de bug: modo range aceita tanto :N:M quanto :N-M.
function M.parse(arg)
  -- Modo intervalo: path:N:M (dois-pontos) ou path:N-M (hífen)
  local path_range, ls_str, le_str
  path_range, ls_str, le_str = arg:match("^(.-)%:(%d+)%:(%d+)$")
  if not path_range then
    -- Correção: aceita hífen entre os números (ex: arquivo.lua:10-20)
    path_range, ls_str, le_str = arg:match("^(.-)%:(%d+)%-(%d+)$")
  end
  if path_range then
    return {
      path = path_range,
      mode = "range",
      ls   = tonumber(ls_str),
      le   = tonumber(le_str),
    }
  end

  -- Leitura completa
  return { path = arg, mode = "full" }
end

return M
