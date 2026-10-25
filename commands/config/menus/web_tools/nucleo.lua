-- commands/config/menus/web_tools/nucleo.lua — cabeçalho (requires e constantes) do módulo.
return function(M)
  local ui         = require("commands.models.ui")
  local config_mod = require("config")
  local c = ui.c
  local SEP  = string.rep("─", 45)
  local SEP2 = string.rep("─", 30)

  local N = {}
  N.ui = ui
  N.config_mod = config_mod
  N.c = c
  N.SEP = SEP
  N.SEP2 = SEP2
  return N
end
