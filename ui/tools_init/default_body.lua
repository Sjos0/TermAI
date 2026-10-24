-- ui/tools_init/default_body.lua — Corpo padrão de um card (Grep, Read, etc.), via componente Card.
local core = require("ui.core")
local card = require("ui.card")
local c    = core.c

local M = {}

function M.render_default_body(lines, tw)
  for _, row in ipairs(card.body_rows(lines, tw)) do
    if row.dim then
      io.write(c.gray .. row.prefix .. c.dim .. row.text .. c.reset .. "\n")
    else
      io.write(c.gray .. row.prefix .. c.white .. row.text .. c.reset .. "\n")
    end
  end
end

return M
