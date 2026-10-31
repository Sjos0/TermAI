-- ui/widgets/layout.lua — distribuição de segmentos (#250, #277).
local largura = require("ui.largura")
local M = {}

function M.split_equal(total, n)
  if n <= 0 or total <= 0 then return {} end
  local base = math.floor(total / n)
  local rem = total - base * n
  local out = {}
  for i = 1, n do out[i] = base + (i <= rem and 1 or 0) end
  return out
end

--- Larguras naturais + espaço livre nos intervalos (esq / centro / dir).
--- segments[1] à esquerda, último à direita, meio centrado se houver 3.
function M.place_natural(segments, inner_w)
  segments = segments or {}
  local n = #segments
  if n == 0 or inner_w <= 0 then return string.rep(" ", math.max(0, inner_w or 0)) end
  local widths = {}
  local need = 0
  for i, seg in ipairs(segments) do
    local w = largura.colunas(tostring(seg or ""))
    widths[i] = w
    need = need + w
  end
  local free = inner_w - need
  if free < 0 then
    -- não cabe: devolve nil para o chamador cortar segmentos
    return nil, widths, need
  end
  local parts = {}
  if n == 1 then
    local pad = free
    local left = math.floor(pad / 2)
    parts[1] = string.rep(" ", left) .. tostring(segments[1]) .. string.rep(" ", pad - left)
  elseif n == 2 then
    parts[1] = tostring(segments[1]) .. string.rep(" ", free) .. tostring(segments[2])
  else
    -- tokens | tempo | relógio: espaço livre dividido entre os dois intervalos
    local gap1 = math.floor(free / 2)
    local gap2 = free - gap1
    parts[1] = tostring(segments[1])
    parts[2] = string.rep(" ", gap1) .. tostring(segments[2]) .. string.rep(" ", gap2)
    parts[3] = tostring(segments[3])
  end
  local line = table.concat(parts)
  local vis = largura.colunas(line)
  if vis < inner_w then line = line .. string.rep(" ", inner_w - vis)
  elseif vis > inner_w then line = largura.cortar(line, inner_w) end
  return line, widths, need
end

function M.place(segments, widths, inner_w)
  segments = segments or {}
  widths = widths or M.split_equal(inner_w or 0, #segments)
  local parts = {}
  for i, seg in ipairs(segments) do
    local w = widths[i] or 0
    if w < 0 then w = 0 end
    local s = tostring(seg or "")
    if largura.colunas(s) > w then s = largura.cortar(s, w)
    else
      local pad = w - largura.colunas(s)
      local left = math.floor(pad / 2)
      s = string.rep(" ", left) .. s .. string.rep(" ", pad - left)
    end
    parts[#parts + 1] = s
  end
  local line = table.concat(parts)
  local vis = largura.colunas(line)
  local limit = inner_w or vis
  if vis < limit then line = line .. string.rep(" ", limit - vis)
  elseif vis > limit then line = largura.cortar(line, limit) end
  return line
end

return M
