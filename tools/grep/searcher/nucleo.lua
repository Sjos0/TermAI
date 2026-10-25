-- tools/grep/searcher/nucleo.lua — cabeçalho (requires e constantes) do módulo.
return function(M)
  local pattern_mod = require("tools.grep.pattern")
  local redact      = require("tools.subagents.redact")
  local SENSITIVE_NAMES = { ["config.json"] = true }

  local N = {}
  N.pattern_mod = pattern_mod
  N.redact = redact
  N.SENSITIVE_NAMES = SENSITIVE_NAMES
  return N
end
