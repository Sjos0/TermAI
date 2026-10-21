-- tools/subagents/spawn.lua — Handler de sessions_spawn: valida e delega ao runner.
local runner = require("tools.subagents.runner")

local M = {}

-- Retorna a resposta final do clone, ou uma mensagem de erro iniciada por ❌.
function M.spawn(args, parent)
  args = type(args) == "table" and args or {}
  local task = args.task
  if type(task) ~= "string" or task:match("^%s*$") then
    return "❌ sessions_spawn: parâmetro 'task' (string) é obrigatório."
  end
  if not parent then
    return "❌ sessions_spawn: nenhum agente ativo para clonar."
  end
  if parent.is_subagent then
    return "❌ sessions_spawn: profundidade máxima=1; um clone não pode criar outro clone."
  end

  local text, err = runner.run(parent, task)
  if not text then return "❌ subagente: " .. tostring(err) end
  return text
end

return M
