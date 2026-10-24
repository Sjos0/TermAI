-- ui/tools_init/default_body.lua — Corpo padrão de um card (Grep, Read, etc.), via componente Card.
local core = require("ui.core")
local card = require("ui.card")
local c    = core.c

local M = {}

-- Último card desenhado: o Ctrl+O mostra o corpo completo dele, sem redesenhar nada antigo.
local last = nil

function M.render_default_body(lines, tw)
  last = { lines = lines, tw = tw }
  for _, row in ipairs(card.body_rows(lines, tw)) do
    if row.dim then
      io.write(c.gray .. row.prefix .. c.dim .. row.text .. c.reset .. "\n")
    else
      io.write(c.gray .. row.prefix .. c.white .. row.text .. c.reset .. "\n")
    end
  end
end

-- Ctrl+O: imprime abaixo do último card o corpo completo (sem recolher). Devolve false se não há card.
function M.expand()
  if not last then return false end
  io.write("\n")
  for _, row in ipairs(card.body_rows(last.lines, last.tw, math.huge)) do
    io.write(core.c.gray .. row.prefix .. core.c.white .. row.text .. core.c.reset .. "\n")
  end
  return true
end

return M
