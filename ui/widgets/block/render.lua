-- ui/widgets/block/render.lua — moldura + bg/fg/frame + wrap (#248, #269, #278).
local largura = require("ui.largura")
local borders = require("ui.widgets.block.borders")
local symbols = require("ui.widgets.block.symbols")

local M = {}
local RESET = "\27[0m"

local function rep_h(ch, n)
  if n <= 0 then return "" end
  return string.rep(ch, n)
end

local function pad_to(s, w)
  local vis = largura.colunas(s)
  if vis >= w then return largura.cortar(s, w) end
  return s .. string.rep(" ", w - vis)
end


local wrap_mod = require("ui.widgets.block.wrap")
local wrap_text = wrap_mod.wrap_text

-- Reaplica fundo do interior após qualquer reset na linha.
local function interior_bg(bg)
  if not bg or bg == "" then return "" end
  return bg
end

function M.lines(area, opts)
  opts = opts or {}
  local flags = opts.borders or borders.ALL
  local set = symbols[opts.border_type or "PLAIN"] or symbols.PLAIN
  local color = opts.border_color or ""
  local bg = opts.bg or ""
  local fg = opts.fg or ""
  local frame_bg = opts.frame_bg or ""
  local frame_fg = opts.frame_fg or color
  local w = area.w or 0
  if w <= 0 then return {} end

  local has_t = borders.has(flags, borders.TOP)
  local has_b = borders.has(flags, borders.BOTTOM)
  local has_l = borders.has(flags, borders.LEFT)
  local has_r = borders.has(flags, borders.RIGHT)
  local border_rows = (has_t and 1 or 0) + (has_b and 1 or 0)
  local side = (has_l and 1 or 0) + (has_r and 1 or 0)
  local inner_w = math.max(0, w - side)

  local raw = opts.content_lines or {}
  local content = {}
  for _, piece in ipairs(raw) do
    for _, ln in ipairs(wrap_text(piece, inner_w)) do content[#content + 1] = ln end
  end
  if #content == 0 then content[1] = "" end

  local h = area.h
  if h == nil or h <= 0 then h = #content + border_rows end
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
      -- Contorno: frame_bg preenche; senão bg legado
      local fbg = frame_bg ~= "" and frame_bg or bg
      local ffg = frame_fg ~= "" and frame_fg or color
      line = fbg .. ffg .. prefix .. mid .. suffix .. RESET
    else
      local body_i = row - (has_t and 1 or 0)
      local body = content[body_i] or ""
      local body_pad = pad_to(body, inner_w)
      local fbg = frame_bg ~= "" and frame_bg or bg
      local ffg = frame_fg ~= "" and frame_fg or color
      local left = has_l and (fbg .. ffg .. set.vertical .. RESET) or ""
      local right = has_r and (fbg .. ffg .. set.vertical .. RESET) or ""
      local ibg = interior_bg(bg)
      local body_s = ibg .. (fg ~= "" and (fg .. body_pad .. RESET .. ibg) or body_pad) .. RESET
      line = left .. body_s .. right
    end
    local plain = line:gsub("\27%[[0-9;:?]*[A-Za-z]", "")
    local vis = largura.colunas(plain)
    if vis < w then
      local pad_bg = (frame_bg ~= "" and is_top or is_bot) and (frame_bg ~= "" and frame_bg or bg) or bg
      if is_top or is_bot then pad_bg = frame_bg ~= "" and frame_bg or bg end
      line = line .. (pad_bg ~= "" and (pad_bg .. string.rep(" ", w - vis) .. RESET) or string.rep(" ", w - vis))
    end
    out[#out + 1] = line
  end
  return out
end

return M
