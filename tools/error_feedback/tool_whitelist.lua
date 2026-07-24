-- tools/error_feedback/tool_whitelist.lua
-- Ferramentas que aceitam argumento vazio sem gerar falso positivo.
local M = {}

local whitelist = {
  sessoes_listar    = true,
  List              = true,
  sessao_status     = true,
  sessoes_historico = true,
  restart           = true,
}

function M.accepts_empty_arg(tool_name)
  if not tool_name then return false end
  return whitelist[tool_name] == true
end

return M
