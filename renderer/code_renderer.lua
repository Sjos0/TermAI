-- code_renderer.lua — Blocos ``` como card de fundo cinza contínuo (igual tool/user).
-- Cada linha já sai com pad até tw colunas via ui.card.bg_row.
-- Quem exibe (ui/messages) NÃO deve re-wrap nem word-stream essas linhas.
local M = {}

local ESC = "\27["
local card

local function get_card()
  if not card then
    local ok, mod = pcall(require, "ui.card")
    card = ok and mod or nil
  end
  return card
end

local function vis_len(s)
  s = tostring(s or ""):gsub("\27%[[0-9;]*m", "")
  local ok, core = pcall(require, "ui.core")
  if ok and core and core.wlen then return core.wlen(s) end
  if utf8 and utf8.len then return utf8.len(s) or #s end
  return #s
end

local function wrap_code(s, w)
  s = tostring(s or "")
  if w < 1 then return { s } end
  if vis_len(s) <= w then return { s } end
  local segs = {}
  if utf8 and utf8.len and utf8.offset then
    -- Corta por colunas visuais aproximadas (1 char ≈ 1 col; wide chars raros em código)
    local n = utf8.len(s) or #s
    local i = 1
    while i <= n do
      local j = math.min(i + w - 1, n)
      local a = utf8.offset(s, i) or 1
      local b = utf8.offset(s, j + 1)
      segs[#segs + 1] = b and s:sub(a, b - 1) or s:sub(a)
      i = j + 1
    end
    return segs
  end
  while vis_len(s) > w do
    segs[#segs + 1] = s:sub(1, w)
    s = s:sub(w + 1)
  end
  if #s > 0 then segs[#segs + 1] = s end
  return segs
end

local function tw()
  local ok, core = pcall(require, "ui.core")
  if ok and core and core.tw then return core.tw() end
  local f = io.popen("stty size 2>/dev/null")
  if f then
    local o = f:read("*a"); f:close()
    local _, w = o:match("(%d+)%s+(%d+)")
    return tonumber(w) or 80
  end
  return 80
end

local function bg_code()
  local ok, core = pcall(require, "ui.core")
  if ok and core and core.c and core.c.bg_code then return core.c.bg_code end
  if ok and core and core.c and core.c.bg_user then return core.c.bg_user end
  return ESC .. "48;5;236m"
end

local function bg_line(fg, text, width)
  local c = get_card()
  if c and c.bg_row then
    return c.bg_row(bg_code(), fg, " ", fg, tostring(text or ""), width)
  end
  -- Fallback sem ui.card: pad explícito (mesmo contrato do bg_row)
  local body = " " .. tostring(text or "")
  local pad = math.max(0, width - 1 - vis_len(body))
  return bg_code() .. fg .. body .. string.rep(" ", pad) .. ESC .. "0m"
end

local function code_fence(lang)
  local label = (lang and lang ~= "") and ("``` " .. lang) or "```"
  return bg_line(ESC .. "38;5;244m", label, tw())
end

local function code_line(s, width)
  width = width or tw()
  local segs = wrap_code(s, math.max(1, width - 2))
  local out = {}
  for _, seg in ipairs(segs) do
    out[#out + 1] = bg_line(ESC .. "38;5;252m", seg, width)
  end
  return table.concat(out, "\n")
end

M.vis_len    = vis_len
M.wrap_code  = wrap_code
M.tw         = tw
M.code_fence = code_fence
M.code_line  = code_line
-- Helper para ui/messages: linha já é card de código (não re-wrap).
function M.is_code_card_line(line)
  return type(line) == "string" and line:find("\27[48;5;", 1, true) ~= nil
end

return M
