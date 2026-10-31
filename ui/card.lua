-- ui/card.lua — Componente Card reutilizável: cada tool é um card.
-- Largura visual via ui/largura.lua (emoji/CJK = 2 colunas).
local largura = require("ui.largura")
local fundo = require("ui.estilo.fundo")
local M = {}

M.MAX_BODY = 5

function M.cut(s, max)
  return largura.cortar(s, max)
end

function M.width(s)
  return largura.colunas(s)
end

function M.header_parts(name, arg, tw)
  local avail = math.max(1, tw - 3)
  local name_s = M.cut(name, avail)
  local rest = avail - M.width(name_s)
  local arg_s = (arg and rest > 3) and M.cut(" (" .. arg .. ")", rest) or ""
  return name_s, arg_s
end

function M.body_rows(lines, tw, max)
  max = max or M.MAX_BODY
  local rows = {}
  local visible = math.min(#lines, max)
  local body_w = math.max(1, tw - 8)
  for i = 1, visible do
    local prefix = (i == visible and #lines <= max) and " └─ " or " │ "
    rows[#rows + 1] = { prefix = prefix, text = M.cut(lines[i], body_w) }
  end
  if #lines > max then
    local hidden = #lines - max
    rows[#rows + 1] = {
      prefix = " └─ ",
      text = "... (" .. hidden .. (hidden == 1 and " linha)" or " linhas)"),
      dim = true,
    }
  end
  return rows
end

function M.bg_row(bg, prefix_color, prefix, text_color, text, tw)
  local visible = M.width(prefix) + M.width(text)
  local pad = math.max(0, tw - 1 - visible)
  local body = prefix_color .. prefix .. text_color .. text .. string.rep(" ", pad)
  body = fundo.fundo_seguro(bg, body)
  return bg .. body .. "\27[0m"
end

return M
