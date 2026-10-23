-- tools/subagents/error_class.lua — Classe do erro de um run (issue #96). Pura, sem I/O.
-- Os padrões vêm de logs reais: "Sem resposta do servidor" é rede; quando nada casa, é "provider".
local M = {}

local RULES = {
  { "rate_limit",       { "429", "rate limit", "rate_limit" } },
  { "context_overflow", { "contexto estourou", "context_overflow", "context window" } },
  { "timeout",          { "runtimeoutseconds", "timeout" } },
  { "killed",           { "process_exit", "killed", "sigterm" } },
  { "network",          { "sem resposta", "conex", "network", "connection" } },
}

function M.of(err)
  local lower = tostring(err or ""):lower()
  for _, rule in ipairs(RULES) do
    for _, pat in ipairs(rule[2]) do
      if lower:find(pat, 1, true) then return rule[1] end
    end
  end
  return "provider"
end

return M
