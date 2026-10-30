-- ui/widgets/layout.lua — distribuição proporcional de segmentos.
local largura = require("ui.largura")
local M = {}

--- Divide total em n fatias; soma = total; diferença máx entre fatias = 1.
function M.split_equal(total, n)
  if n <= 0 or total <= 0 then return {} end
  local base = math.floor(total / n)
  local rem = total - base * n
  local out = {}
  for i = 1, n do
    out[i] = base + (i <= rem and 1 or 0)
  end
  return out
end

--- Coloca segmentos (strings) em larguras dadas; trunca com … se precisar.
--- segments: array de strings; widths: array de larguras; inner_w: limite total.
function M.place(segments, widths, inner_w)
  segments = segments or {}
  widths = widths or M.split_equal(inner_w or 0, #segments)
  local parts = {}
  local used = 0
  for i, seg in ipairs(segments) do
    local w = widths[i] or 0
    if w < 0 then w = 0 end
    local s = tostring(seg or "")
    if largura.colunas(s) > w then
      s = largura.cortar(s, w)
    else
      -- centraliza no slot
      local pad = w - largura.colunas(s)
      local left = math.floor(pad / 2)
      s = string.rep(" ", left) .. s .. string.rep(" ", pad - left)
    end
    parts[#parts + 1] = s
    used = used + w
  end
  local line = table.concat(parts)
  local vis = largura.colunas(line)
  local limit = inner_w or vis
  if vis < limit then
    line = line .. string.rep(" ", limit - vis)
  elseif vis > limit then
    line = largura.cortar(line, limit)
  end
  return line
end

return M
