-- agent/compaction/nucleo.lua — cabeçalho (requires e constantes) do módulo.
return function(M)
  local api            = require("agent.api")
  local session        = require("session")
  local mf             = require("memoryflush")
  local cutpoint       = require("agent.compaction.cutpoint")
  local poda           = require("agent.compaction.poda")
  local serialize      = require("agent.compaction.serialize")
  local summary_merge  = require("agent.compaction.summary_merge")
  local filetracking   = require("agent.compaction.filetracking")
  local confirm        = require("agent.compaction.confirm")
  local splitturn      = require("agent.compaction.splitturn")
  local MAX_TENTATIVAS_SEM_PROGRESSO <const> = 2
  local CUSTOM_INSTRUCTIONS_MAX_CHARS <const> = 500

  local N = {}
  N.api = api
  N.session = session
  N.mf = mf
  N.cutpoint = cutpoint
  N.poda = poda
  N.serialize = serialize
  N.summary_merge = summary_merge
  N.filetracking = filetracking
  N.confirm = confirm
  N.splitturn = splitturn
  N.MAX_TENTATIVAS_SEM_PROGRESSO = MAX_TENTATIVAS_SEM_PROGRESSO
  N.CUSTOM_INSTRUCTIONS_MAX_CHARS = CUSTOM_INSTRUCTIONS_MAX_CHARS
  return N
end
