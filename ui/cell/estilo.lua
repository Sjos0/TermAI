-- ui/cell/estilo.lua — SGR de texto do card (puro).
local M = {}

function M.sgr_fg(code)
  if not code then return "" end
  return string.format("\27[38;5;%dm", code)
end

function M.sgr_bg(code)
  if not code then return "" end
  return string.format("\27[48;5;%dm", code)
end

function M.reset()
  return "\27[0m"
end

return M
