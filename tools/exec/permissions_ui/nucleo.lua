-- tools/exec/permissions_ui/nucleo.lua — cabeçalho (requires e constantes) do módulo.
return function(M)
  local suggest          = require("agent.hooks.bash_patterns.suggest")
  local approval_backend = require("agent.hooks.approval_backend")

  local N = {}
  N.suggest = suggest
  N.approval_backend = approval_backend
  return N
end
