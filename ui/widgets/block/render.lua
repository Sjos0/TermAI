-- ui/widgets/block/render.lua — moldura + bg/fg + wrap por palavra (#248, #269).
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

-- Quebra por palavra dentro de max_w; palavra > max_w quebra por caractere visível.
local function wrap_text(text, max_w)
  if max_w <= 0 then return {} end
  text = tostring(text or "")
  local lines = {}
  local function push(chunk)
    if chunk == "" and #lines > 0 then return end
    lines[#lines + 1] = chunk
  end
  for paragraph in (text .. "\n"):gmatch("([^\n]*)\n") do
    if paragraph == "" then
      push("")
    else
      local cur = ""
      for word in paragraph:gmatch("%S+%s*") do
        local candidate = cur .. word
        if largura.colunas(candidate) <= max_w then
          cur = candidate
        else
          if cur ~= "" then push(cur:gsub("%s+$", "")) end
          -- palavra isolada maior que max_w: cortar por colunas
          while largura.colunas(word) > max_w do
            local piece = largura.cortar(word, max_w)
            push(piece)
            -- remove o prefixo visualmente cortado (aprox. por bytes do piece)
            local plen = #piece
            while plen > 0 and largura.colunas(word:sub(1, plen)) > max_w do
              plen = plen - 1
            end
            word = word:sub(plen + 1)
          end
          cur = word
        end
      end
      if cur ~= "" then push(cur:gsub("%s+$", "")) end
    end
  end
  if #lines == 0 then lines[1] = "" end
  return lines
end

function M.lines(area, opts)
  opts = opts or {}
  local flags = opts.borders or borders.ALL
  local set = symbols[opts.border_type or "PLAIN"] or symbols.PLAIN
  local color = opts.border_color or ""
  local bg = opts.bg or ""
  local fg = opts.fg or ""
  local reset = "\27[0m"
  local w = area.w or 0
  if w <= 0 then return {} end

  local has_t = borders.has(flags, borders.TOP)
  local has_b = borders.has(flags, borders.BOTTOM)
  local has_l = borders.has(flags, borders.LEFT)
  local has_r = borders.has(flags, borders.RIGHT)
  local border_rows = (has_t and 1 or 0) + (has_b and 1 or 0)
  local side = (has_l and 1 or 0) + (has_r and 1 or 0)
  local inner_w = math.max(0, w - side)

  -- wrap do conteúdo para inner_w
  local raw = opts.content_lines or {}
  local content = {}
  for _, piece in ipairs(raw) do
    for _, ln in ipairs(wrap_text(piece, inner_w)) do
      content[#content + 1] = ln
    end
  end
  if #content == 0 then content[1] = "" end

  local h = area.h
  if h == nil or h <= 0 then
    h = #content + border_rows
  end
  if h <= 0 then return {} end

  local out = {}
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
      if is_top and opts.title and has_t and mid_w > 4 then
        local t = " " .. tostring(opts.title) .. " "
        t = largura.cortar(t, mid_w)
        local tw = largura.colunas(t)
        local left_pad = math.floor((mid_w - tw) / 2)
        mid = rep_h(set.horizontal, left_pad) .. t
          .. rep_h(set.horizontal, math.max(0, mid_w - left_pad - tw))
      end
      -- borda + fundo em todas as células
      line = bg .. color .. prefix .. mid .. suffix .. reset
    else
      local body_i = row - (has_t and 1 or 0)
      local body = content[body_i] or ""
      local mid_w = inner_w
      local prefix, suffix = "", ""
      if has_l then prefix = color .. set.vertical .. reset end
      if has_r then suffix = color .. set.vertical .. reset end
      local body_pad = pad_to(body, mid_w)
      -- fundo cobre prefixo, corpo e sufixo
      line = bg .. prefix .. (fg ~= "" and (fg .. body_pad .. reset .. bg) or body_pad) .. suffix .. reset
    end
    local plain = line:gsub("\27%[[0-9;:?]*[A-Za-z]", "")
    local vis = largura.colunas(plain)
    if vis < w then
      line = line .. (bg ~= "" and (bg .. string.rep(" ", w - vis) .. reset) or string.rep(" ", w - vis))
    end
    out[#out + 1] = line
  end
  return out
end

return M
