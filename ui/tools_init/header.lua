-- ui/tools_init/header.lua — Cabeçalho de uma tool: sempre UMA linha, cortada na largura da tela.
-- Cabeçalho que quebra desalinha a volta do cursor (ESC[nA) e deixa resíduo na TUI.
local core = require("ui.core")
local card = require("ui.card")
local c    = core.c

local M = {}

function M.cut_cols(s, max) return card.cut(s, max) end

-- Sempre 1 linha visual: write_header corta o texto para caber em tw.
function M.header_vis_len(name, arg, tw)
  return 1
end

function M.write_header(dot_color, name, arg)
  local tw     = core.tw()
  local avail  = tw - 3                            -- "⬤ " e uma coluna de folga
  local name_s = M.cut_cols(name, math.max(1, avail))
  local rest   = avail - (utf8.len(name_s) or #name_s)
  local arg_s  = (arg and rest > 3) and M.cut_cols(" (" .. arg .. ")", rest) or ""
  local prefix = "⬤ "
  local text   = name_s .. arg_s
  -- Fundo do card no cabeçalho (live e replay ficam iguais).
  io.write(card.bg_row(c.bg, dot_color, prefix, c.bold .. c.white, text, tw) .. "\n")
end

return M
