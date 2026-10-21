-- ui/subagent.lua — Linhas aninhadas das ferramentas de um clone: 3 visíveis + contador.
local core = require("ui.core")
local c    = core.c

local M = {}
local VISIBLE = 3
local state = { printed = 0, hidden = 0 }

-- Mostra o nome da ferramenta do clone, sem corpo de resultado.
function M.child_start(disp)
  if state.printed < VISIBLE then
    state.printed = state.printed + 1
    io.write(c.gray .. " │ " .. c.reset .. c.white .. disp:sub(1, core.tw() - 8) .. c.reset .. "\n")
    io.flush()
  else
    state.hidden = state.hidden + 1
  end
end

-- Resultado do clone não é exibido; só o nome da ferramenta importa.
function M.child_end() end

-- Escreve o contador de ocultas e devolve quantas linhas o clone ocupou abaixo do cabeçalho.
function M.finish_lines()
  local lines = state.printed
  if state.hidden > 0 then
    io.write(c.gray .. " └ " .. c.dim .. "... (+" .. state.hidden .. " ferramentas)" .. c.reset .. "\n")
    lines = lines + 1
  end
  state = { printed = 0, hidden = 0 }
  io.flush()
  return lines
end

return M
