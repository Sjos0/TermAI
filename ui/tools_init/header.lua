-- ui/tools_init/header.lua — Renderização e cálculo de dimensões do cabeçalho da ferramenta.
local core = require("ui.core")
local c    = core.c

local M = {}

function M.header_vis_len(name, arg)
  if arg then return 5 + #name + #arg end
  return 2 + #name
end

function M.write_header(dot_color, name, arg)
  io.write(dot_color .. "⬤ " .. c.reset .. c.bold .. c.white .. name .. c.reset)
  if arg then
    io.write(c.white .. " (" .. arg .. ")" .. c.reset)
  end
  io.write("\n")
end

return M
