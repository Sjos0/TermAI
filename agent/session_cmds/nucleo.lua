-- agent/session_cmds/nucleo.lua — cabeçalho (requires e constantes) do módulo.
return function(M)
  local ui            = require("ui")
  local session       = require("session")
  local prompt_module = require("prompt")
  local tools         = require("tools")
  local mf            = require("memoryflush")
  local restart_mod   = require("agent.restart")
  local REPLAY_N = 15

  local N = {}
  N.ui = ui
  N.session = session
  N.prompt_module = prompt_module
  N.tools = tools
  N.mf = mf
  N.restart_mod = restart_mod
  N.REPLAY_N = REPLAY_N
  return N
end
