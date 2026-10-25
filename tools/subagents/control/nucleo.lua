-- tools/subagents/control/nucleo.lua — cabeçalho (requires e constantes) do módulo.
return function(M)
  local registry  = require("tools.subagents.registry")
  local scheduler = require("tools.subagents.scheduler")
  local launcher  = require("tools.subagents.launcher")
  local events    = require("tools.subagents.events")
  local announce  = require("tools.subagents.announce")
  local json      = require("json")
  local card      = require("tools.subagents.card")
  local redact    = require("tools.subagents.redact")
  local log       = require("diag.log")
  local N = {}
  N.registry = registry
  N.scheduler = scheduler
  N.launcher = launcher
  N.events = events
  N.announce = announce
  N.json = json
  N.card = card
  N.redact = redact
  N.log = log
  return N
end
