-- ui/spinner/retry.lua — lógica de retry e contadores de linhas.
local core = require("ui.core")
local c = core.c
local M = {}

local _retry_lines = 0

--- Exibe aviso de tentativa de retry e, opcionalmente, contagem regressiva.
function M.show_retry(attempt, max, reason, wait)
  local orange = "\27[38;5;208m"
  io.write(orange .. "  ⚠ Tentativa " .. attempt .. "/" .. max
    .. " — " .. reason .. c.reset .. "\n")
  _retry_lines = _retry_lines + 1
  if wait > 0 then
    io.write(c.gray .. "  ⏳ Aguardando " .. wait .. "s..." .. c.reset .. "\n")
    _retry_lines = _retry_lines + 1
  end
  io.flush()
end

--- Limpa as linhas de retry anteriores no terminal.
function M.clear_retry_lines()
  if _retry_lines > 0 then
    io.write(string.format("\27[%dA\27[J", _retry_lines))
    io.flush()
    _retry_lines = 0
  end
end

return M
