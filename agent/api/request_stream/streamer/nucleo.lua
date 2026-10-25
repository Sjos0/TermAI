-- agent/api/request_stream/streamer/nucleo.lua — cabeçalho (requires e constantes) do módulo.
return function(M)
  local json            = require("json")
  local ui              = require("ui")
  local thinking_parser = require("ui.thinking_parser")
  local utils           = require("agent.api.utils")
  local payload_mod     = require("agent.api.payload")
  local sync_mod        = require("agent.api.request_sync")
  local tool_parser     = require("agent.api.request_stream.tool_parser")
  local recovery        = require("agent.api.request_stream.recovery")
  local tokens_mod      = require("agent.api.request_stream.tokens")
  local error_log       = require("agent.api.request_stream.error_log")

  local N = {}
  N.json = json
  N.ui = ui
  N.thinking_parser = thinking_parser
  N.utils = utils
  N.payload_mod = payload_mod
  N.sync_mod = sync_mod
  N.tool_parser = tool_parser
  N.recovery = recovery
  N.tokens_mod = tokens_mod
  N.error_log = error_log
  return N
end
