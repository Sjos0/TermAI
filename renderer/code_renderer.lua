-- code_renderer.lua — Blocos de código com fundo cinza contínuo (estilo card).
-- Pad com espaços até a largura do terminal: ESC[K em vários terminais (Termux)
-- limpa com fundo DEFAULT (preto), gerando "buracos" pretos no card cinza.
local M = {}

local ESC = "\27["

local function vis_len(s)
  return #(tostring(s or ""):gsub("\27%[[0-9;]*m", ""))
end

local function wrap_code(s, w)
  s = tostring(s or "")
  if w < 1 then return { s } end
  if vis_len(s) <= w then return { s } end
  -- Corta por caracteres UTF-8 quando possível (evita quebrar emoji no meio).
  local segs = {}
  if utf8 and utf8.len and utf8.offset then
    local n = utf8.len(s) or #s
    local i = 1
    while i <= n do
      local j = math.min(i + w - 1, n)
      local a = utf8.offset(s, i) or 1
      local b = utf8.offset(s, j + 1)
      local chunk = b and s:sub(a, b - 1) or s:sub(a)
      segs[#segs + 1] = chunk
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
  local ok, core_mod = pcall(require, "ui.core")
  if ok and core_mod and core_mod.tw then
    return core_mod.tw()
  end
  local f = io.popen("stty size 2>/dev/null")
  if f then
    local o = f:read("*a"); f:close()
    local _, w = o:match("(%d+)%s+(%d+)")
    return tonumber(w) or 80
  end
  return 80
end

local function bg_code()
  local ok, core_mod = pcall(require, "ui.core")
  if ok and core_mod and core_mod.c and core_mod.c.bg_code then
    return core_mod.c.bg_code
  end
  return ESC .. "48;5;236m"
end

-- Uma linha de fundo cinza, texto cortado/padded até width colunas.
local function bg_line(fg, text, width)
  local body = " " .. tostring(text or "")
  local pad = math.max(0, width - 1 - vis_len(body))
  return bg_code() .. fg .. body .. string.rep(" ", pad) .. ESC .. "0m"
end

local function code_fence(lang)
  local label = (lang and lang ~= "") and ("``` " .. lang) or "```"
  local width = tw()
  return bg_line(ESC .. "38;5;244m", label, width)
end

local function code_line(s, width)
  width = width or tw()
  local segs = wrap_code(s, width - 2)
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
return M
