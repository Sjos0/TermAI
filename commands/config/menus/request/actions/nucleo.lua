-- commands/config/menus/request/actions/nucleo.lua — cabeçalho (requires e constantes) do módulo.
return function(M)
  local ui         = require("commands.models.ui")
  local api        = require("agent.api")
  local saver      = require("commands.config.menus.request.saver")
  local c = ui.c

  local N = {}
  N.ui = ui
  N.api = api
  N.saver = saver
  N.c = c
  return N
end
