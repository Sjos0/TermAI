-- tools/todo/archiver.lua — Arquiva uma lista de todos concluída na memória de longo prazo.
-- Formato simples e seguro (não depende do pipeline completo do memoryflush,
-- cujo formatter exato ainda não foi auditado).
local io_utils = require("tools.memory.io_utils")

local M = {}

-- Acrescenta um bloco com a lista concluída ao arquivo de memória do dia.
function M.archive(todos)
  local hoje = os.date("%Y-%m-%d")
  local path = io_utils.MEMORY_DIR .. "/" .. hoje .. ".md"

  local linhas = {"\n## [[todo_concluida]] " .. os.date("%Y-%m-%d %H:%M")}
  for _, item in ipairs(todos) do
    linhas[#linhas + 1] = "- [x] " .. item.content
  end
  local bloco = table.concat(linhas, "\n") .. "\n"

  local f = io.open(path, "a")
  if not f then return false end
  f:write(bloco)
  f:close()
  return true
end

return M
