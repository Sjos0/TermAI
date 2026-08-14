-- tools/exec/permissions/session.lua — Estado em memória da sessão atual
-- Permissões de ferramentas e regras bash temporárias (não persistidas).
local M = {}

-- Permissões temporárias (em memória para a sessão atual)
-- Chaves de ferramenta: status ("always" | "blocked" | nil)
-- Chaves de regras: "bashRules_allow" / "bashRules_deny" → arrays de padrões
local session_perms = {}

function M.get_status(tool_name)
  return session_perms[tool_name]
end

function M.set_status(tool_name, status)
  session_perms[tool_name] = status
end

function M.get_rules(behavior)
  local key = "bashRules_" .. behavior
  return session_perms[key] or {}
end

function M.set_rules(behavior, list)
  local key = "bashRules_" .. behavior
  session_perms[key] = list
end

return M
