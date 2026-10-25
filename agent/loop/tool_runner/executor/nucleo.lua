-- agent/loop/tool_runner/executor/nucleo.lua — cabeçalho (requires e constantes) do módulo.
return function(M)
  local ui        = require("ui")
  local tools_mod = require("tools")
  local json      = require("json")
  local display   = require("agent.loop.tool_runner.display")
  local tracker   = require("agent.loop.tool_runner.tracker")
  local suffix    = require("agent.loop.tool_runner.suffix")
  local subagent_ui = require("ui.subagent")

  local N = {}
  N.ui = ui
  N.tools_mod = tools_mod
  N.json = json
  N.display = display
  N.tracker = tracker
  N.suffix = suffix
  N.subagent_ui = subagent_ui
  return N
end
