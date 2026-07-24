-- ui/tools_init.lua — Renderizador visual de execução de ferramentas (Padrão Fachada).
local M = {}

-- Carrega submódulos especializados de domínio
local executor   = require("ui.tools_init.executor")
local group_read = require("ui.tools_init.group_read")

-- Reexporta a API mapeando idêntico ao contrato original
M.tool_start  = executor.tool_start
M.tool_end    = executor.tool_end
M.tool_replay = executor.tool_replay

-- Incorpora as funções do group_read
for k, v in pairs(group_read) do
  M[k] = v
end

return M
