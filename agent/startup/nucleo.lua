-- agent/startup/nucleo.lua — cabeçalho (requires e constantes) do módulo.
return function(M)
  local ui      = require("ui")
  local session = require("session")
  local api     = require("agent.api")
  local core    = require("ui.core")
  local c       = core.c
  local rr      = require("agent.startup.reasoning_renderer")
  local classif = require("agent.startup.message_classifier")
  local tcm     = require("agent.startup.tc_mapper")
  local REPLAY_N = 40
  local N = {}
  N.ui = ui
  N.session = session
  N.api = api
  N.core = core
  N.c = c
  N.rr = rr
  N.classif = classif
  N.tcm = tcm
  N.REPLAY_N = REPLAY_N
  return N
end
