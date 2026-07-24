-- markdown.lua — Renderização de markdown em ANSI: formatação inline e por linha.
-- render_inline cobre code/bold/italic/bold+italic/underline; render_line cobre
-- headers, separadores, bullets, listas numeradas e blockquotes, delegando o
-- restante a render_inline.
-- Dependências externas: nenhuma (Lua puro).
local M = {}

local ESC = "\27["

local function render_inline(s)
  s = s:gsub("`([^`]+)`",        ESC.."38;5;220m%1"..ESC.."0m")
  s = s:gsub("%*%*%*(.-)%*%*%*", ESC.."1m"..ESC.."3m%1"..ESC.."0m")
  s = s:gsub("%*%*(.-)%*%*",     ESC.."1m%1"..ESC.."22m")
  s = s:gsub("%*(.-)%*",         ESC.."3m%1"..ESC.."23m")
  s = s:gsub("__(.-)__",         ESC.."4m%1"..ESC.."24m")
  return s
end

local function render_line(s)
  if s:match("^#### ") then
    return ESC.."1m"..ESC.."38;5;220m▸ "..render_inline(s:sub(6))..ESC.."0m"
  elseif s:match("^### ") then
    return ESC.."1m"..ESC.."38;5;80m▸▸ "..render_inline(s:sub(5))..ESC.."0m"
  elseif s:match("^## ") then
    return ESC.."1m"..ESC.."38;5;39m▸▸▸ "..render_inline(s:sub(4))..ESC.."0m"
  elseif s:match("^# ") then
    return ESC.."1m"..ESC.."38;5;255m"..render_inline(s:sub(3))..ESC.."0m"
  end
  if s:match("^%-%-%-+$") or s:match("^%*%*%*+$") then
    return ESC.."38;5;238m"..string.rep("─", 40)..ESC.."0m"
  end
  s = s:gsub("^%s*[%-%*•] (.+)$", function(body)
    return "  "..ESC.."38;5;245m•"..ESC.."0m "..render_inline(body)
  end)
  s = s:gsub("^%s*(%d+)%. (.+)$", function(n, body)
    return "  "..ESC.."38;5;245m"..n.."."..ESC.."0m "..render_inline(body)
  end)
  s = s:gsub("^> (.+)$", function(body)
    return ESC.."38;5;245m│ "..ESC.."3m"..render_inline(body)..ESC.."0m"
  end)
  s = render_inline(s)
  return s
end

M.render_inline = render_inline
M.render_line   = render_line
return M
