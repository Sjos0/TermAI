-- commands/config/menus/web_tools/nucleo.lua — cabeçalho (requires e constantes) do módulo.
return function(M)
  local ui         = require("commands.models.ui")
  local config_mod = require("config")
  local c = ui.c
  local core = require("ui.core")
  -- Réguas responsivas (#331): função, não valor — core.tw() é lido a cada uso.
  local function SEP(usado)    return core.regua(45, usado or 2) end
  local function SEP2(prefixo) return core.regua(30, #(prefixo or "")) end


  local N = {}
  N.ui = ui
  N.config_mod = config_mod
  N.c = c
  N.SEP = SEP
  N.SEP2 = SEP2
  return N
end
