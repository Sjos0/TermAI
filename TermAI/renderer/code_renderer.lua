-- code_renderer.lua — Renderização de blocos de código com fundo colorido e word-wrap.
-- vis_len/wrap_code ignoram sequências ANSI ao medir largura visual, garantindo
-- que o wrap não quebre no meio de um código de cor. tw() consulta o terminal
-- via `stty size` para descobrir a largura disponível.
local M = {}

local ESC = "\27["

local function vis_len(s)
  return #(s:gsub("\27%[[0-9;]*m", ""))
end

local function wrap_code(s, w)
  if vis_len(s) <= w then return { s } end
  local segs = {}
  while vis_len(s) > w do segs[#segs + 1] = s:sub(1, w); s = s:sub(w + 1) end
  if #s > 0 then segs[#segs + 1] = s end
  return segs
end

local function tw()
  local f = io.popen("stty size 2>/dev/null")
  if f then
    local o = f:read("*a"); f:close()
    local _, w = o:match("(%d+)%s+(%d+)")
    return tonumber(w) or 80
  end
  return 80
end

local function code_fence(lang)
  local label = (lang and lang ~= "") and ("``` "..lang) or "```"
  return ESC.."48;5;236m"..ESC.."38;5;244m"
      .. " "..label..ESC.."K"..ESC.."0m"
end

local function code_line(s, width)
  local segs = wrap_code(s, width - 1)
  local out  = {}
  for _, seg in ipairs(segs) do
    out[#out + 1] = ESC.."48;5;236m"..ESC.."38;5;252m"
                 .. " "..seg..ESC.."K"..ESC.."0m"
  end
  return table.concat(out, "\n")
end

M.vis_len    = vis_len
M.wrap_code  = wrap_code
M.tw         = tw
M.code_fence = code_fence
M.code_line  = code_line
return M
