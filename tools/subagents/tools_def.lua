-- tools/subagents/tools_def.lua — Schemas e registro das tools de subagentes.
local spawn   = require("tools.subagents.spawn")
local control = require("tools.subagents.control")
local M = {}

function M.register(tools, get_parent)
  tools.register("sessions_spawn",
    "Cria um subagente em background e responde na hora com runId. Sem agentId, clona este agente. "
      .. "Com agentId, roda um agente independente. Clones e agentes rodam em processos próprios, "
      .. "até o limite de simultâneos; o resultado chega depois como mensagem do sistema.",
    function(arg)
      return spawn.spawn(type(arg) == "table" and arg or { task = tostring(arg or "") }, get_parent())
    end,
    { type = "object", properties = {
        task = { type = "string", description = "Tarefa do subagente (obrigatório)." },
        agentId = { type = "string", description = "Agente independente existente. Omita para clonar." },
        label = { type = "string", description = "Rótulo curto para listagem." },
        model = { type = "string", description = "Modelo provider/id (opcional)." },
        cleanup = { type = "string", description = "retain (padrão: guardado por 7 dias ou 50 runs), delete (apaga logo após o anúncio) ou keep (sem limite)." },
        runTimeoutSeconds = { type = "number", description = "Tempo máximo do run em segundos (padrão 600). Limites: 5 simultâneos no total e 5 por agente pai." },
      }, required = { "task" } })

  tools.register("subagents_listar", "Lista os subagentes (opcional: status).",
    function(arg) return control.listar(type(arg) == "table" and arg or {}) end,
    { type = "object", properties = { status = { type = "string" } } })

  tools.register("subagents_info", "Detalhes de um subagente pelo runId.",
    function(arg) return control.info(type(arg) == "table" and arg or { runId = tostring(arg or "") }) end,
    { type = "object", properties = { runId = { type = "string" } }, required = { "runId" } })

  tools.register("subagents_log", "Últimos eventos de um subagente (padrão 20 linhas).",
    function(arg) return control.log(type(arg) == "table" and arg or { runId = tostring(arg or "") }) end,
    { type = "object", properties = { runId = { type = "string" }, linhas = { type = "number" } },
      required = { "runId" } })

  tools.register("subagents_matar", "Encerra um subagente em execução.",
    function(arg) return control.matar(type(arg) == "table" and arg or { runId = tostring(arg or "") }) end,
    { type = "object", properties = { runId = { type = "string" } }, required = { "runId" } })
end

return M
