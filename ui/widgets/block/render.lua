-- ui/widgets/block/render.lua — desenha moldura em linhas de texto (sem I/O).
local largura = require("ui.largura")
local borders = require("ui.widgets.block.borders")
local symbols = require("ui.widgets.block.symbols")

local M = {}

local function rep_h(ch, n)
  if n <= 0 then return "" end
  return string.rep(ch, n)
end

local function pad_to(s, w)
  local vis = largura.colunas(s)
  if vis >= w then return largura.cortar(s, w) end
  return s .. string.rep(" ", w - vis)
end

function M.lines(area, opts)
  opts = opts or {}
  local flags = opts.borders or borders.ALL
  local set = symbols[opts.border_type or "PLAIN"] or symbols.PLAIN
  local color = opts.border_color or ""
  local reset = (color ~= "" and "\27[0m") or ""
  local w = area.w or 0
  local h = area.h or 0
  if w <= 0 or h <= 0 then return {} end

  local has_t = borders.has(flags, borders.TOP)
  local has_b = borders.has(flags, borders.BOTTOM)
  local has_l = borders.has(flags, borders.LEFT)
  local has_r = borders.has(flags, borders.RIGHT)

  local out = {}
  local content = opts.content_lines or {}

  for row = 1, h do
    local is_top = has_t and row == 1
    local is_bot = has_b and row == h
    local line
    if is_top or is_bot then
      local left_c = is_top and set.top_left or set.bottom_left
      local right_c = is_top and set.top_right or set.bottom_right
      local mid_w = w
      local prefix, suffix = "", ""
      if has_l then prefix = left_c; mid_w = mid_w - 1 end
      if has_r then suffix = right_c; mid_w = mid_w - 1 end
      local mid = rep_h(set.horizontal, math.max(0, mid_w))
      -- título só no topo, se pedido e houver espaço
      if is_top and opts.title and has_t and mid_w > 4 then
        local t = " " .. tostring(opts.title) .. " "
        t = largura.cortar(t, mid_w)
        local tw = largura.colunas(t)
        local left_pad = math.floor((mid_w - tw) / 2)
        mid = rep_h(set.horizontal, left_pad) .. t
          .. rep_h(set.horizontal, math.max(0, mid_w - left_pad - tw))
      end
      line = color .. prefix .. mid .. suffix .. reset
    else
      local body_i = row - (has_t and 1 or 0)
      local body = content[body_i] or ""
      local mid_w = w
      local prefix, suffix = "", ""
      if has_l then prefix = color .. set.vertical .. reset; mid_w = mid_w - 1 end
      if has_r then suffix = color .. set.vertical .. reset; mid_w = mid_w - 1 end
      line = prefix .. pad_to(body, mid_w) .. suffix
    end
    -- garantir largura visual w (SGR não conta)
    local plain = line:gsub("\27%[[0-9;]*m", "")
    local vis = largura.colunas(plain)
    if vis < w then
      line = line .. string.rep(" ", w - vis)
    end
    out[#out + 1] = line
  end
  return out
end

return M
