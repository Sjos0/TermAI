-- ui/tools_init/default_body.lua — Renderizador de corpo padrão (Grep, Read, etc.) com limite de linhas.
local core = require("ui.core")
local c    = core.c

local M = {}
local MAX_TOOL_LINES = 5

function M.render_default_body(lines, tw)
  local visible = math.min(#lines, MAX_TOOL_LINES)
  for i = 1, visible do
    local prefix = i == visible and " └─ " or " │ "
    io.write(c.gray .. prefix .. c.white .. lines[i]:sub(1, tw - 8) .. c.reset .. "\n")
  end
  if #lines > MAX_TOOL_LINES then
    io.write(c.gray .. " └─ " .. c.dim .. "... ("
     .. (#lines - MAX_TOOL_LINES) .. " linhas)" .. c.reset .. "\n")
  end
end

return M
