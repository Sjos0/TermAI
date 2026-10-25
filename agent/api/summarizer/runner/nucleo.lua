-- agent/api/summarizer/runner/nucleo.lua — cabeçalho (requires e constantes) do módulo.
return function(M)
  local json       = require("json")
  local utils      = require("agent.api.utils")
  local ui_mod     = require("agent.api.summarizer.ui")
  local serializer = require("agent.api.summarizer.serializer")
  local validator  = require("agent.api.summarizer.validator")

  local N = {}
  N.json = json
  N.utils = utils
  N.ui_mod = ui_mod
  N.serializer = serializer
  N.validator = validator
  return N
end
