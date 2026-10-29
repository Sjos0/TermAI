-- ui/tools_init/header.lua — Cabeçalho de uma tool: sempre UMA linha, cortada na largura da tela.
-- Cabeçalho que quebra desalinha a volta do cursor (ESC[nA) e deixa resíduo na TUI.
local core = require("ui.core")
local card = require("ui.card")
local c    = core.c

local M = {}

function M.cut_cols(s, max) return card.cut(s, max) end

-- Colunas do texto do cabeçalho (antes do corte visual). Usado por specs;
-- tool_end NÃO usa isso para ESC[nA — o header escrito é sempre 1 linha.
function M.header_vis_len(name, arg, tw)
  local full = 2 + (utf8.len(name or "") or #(name or ""))
  if arg then full = full + 3 + (utf8.len(arg) or #arg) end
  if tw then return math.min(full, tw - 1) end
  return full
end

function M.write_header(dot_color, name, arg)
  local tw     = core.tw()
  local avail  = tw - 3
  local name_s = M.cut_cols(name, math.max(1, avail))
  local rest   = avail - (utf8.len(name_s) or #name_s)
  local arg_s  = (arg and rest > 3) and M.cut_cols(" (" .. arg .. ")", rest) or ""
  local prefix = "⬤ "
  local text   = name_s .. arg_s
  -- Fundo do card no cabeçalho (live e replay ficam iguais).
  io.write(card.bg_row(c.bg, dot_color, prefix, c.bold .. c.white, text, tw) .. "\n")
end

return M
