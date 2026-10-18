-- tools/subagents.lua — Fachada das tools de subagentes (Issue #81 MVP).
local spawn   = require("tools.subagents.spawn")
local inspect = require("tools.subagents.inspect")

local M = {}

local function parent_ctx()
  return _G.__termai_ctx
end

function M.register(tools)
  tools.register(
    "sessions_spawn",
    "Spawna um subagente isolado (non-blocking). Retorna imediatamente runId + childSessionKey. "
      .. "O filho executa a 'task' em sessão própria, sem herdar memória do pai. "
      .. "Use subagents_wait ou aguarde announce no transcript para o resultado. "
      .. "Policy: allowAgents + maxConcurrent + maxChildrenPerAgent. Depth máximo = 1.",
    function(arg)
      local args = type(arg) == "table" and arg or { task = tostring(arg or "") }
      return spawn.spawn(args, parent_ctx())
    end,
    {
      type = "object",
      properties = {
        task = { type = "string", description = "Prompt inicial / tarefa do filho (obrigatório)." },
        agentId = { type = "string", description = "Entry em agents.list (default = agent do requester)." },
        model = { type = "string", description = "Override pontual de modelo (provider/id)." },
        label = { type = "string", description = "Rótulo de display opcional." },
        runTimeoutSeconds = { type = "number", description = "Timeout do run em segundos." },
        context = { type = "string", description = "Apenas 'isolated' no MVP." },
      },
      required = { "task" },
    }
  )

  tools.register(
    "subagents_listar",
    "Lista child runs (não confundir com sessoes_listar de conversa). Filtros opcionais: status, parent, agentId.",
    function(arg)
      local args = type(arg) == "table" and arg or {}
      return inspect.listar(args)
    end,
    {
      type = "object",
      properties = {
        status = { type = "string", description = "queued|running|completed|failed|timeout" },
        parent = { type = "string", description = "Filtrar por parent_agent_id" },
        agentId = { type = "string", description = "Filtrar por agentId do filho" },
      },
    }
  )

  tools.register(
    "subagents_status",
    "Status detalhado de um child run por runId.",
    function(arg)
      local args = type(arg) == "table" and arg or { runId = tostring(arg or "") }
      return inspect.status(args)
    end,
    {
      type = "object",
      properties = {
        runId = { type = "string", description = "ID do run retornado por sessions_spawn" },
      },
      required = { "runId" },
    }
  )

  tools.register(
    "subagents_wait",
    "Aguarda um child run chegar a estado terminal (ou timeoutSeconds). Bloqueia o turno do modelo, não a UI humana. Retorna resultado JSON.",
    function(arg)
      local args = type(arg) == "table" and arg or { runId = tostring(arg or "") }
      return inspect.wait(args, parent_ctx())
    end,
    {
      type = "object",
      properties = {
        runId = { type = "string", description = "ID do run" },
        timeoutSeconds = { type = "number", description = "Timeout de espera (default 120)" },
      },
      required = { "runId" },
    }
  )

  tools.register(
    "subagents_cancel",
    "Cancela um child run ainda não terminal (marca failed/cancelled).",
    function(arg)
      local args = type(arg) == "table" and arg or { runId = tostring(arg or "") }
      return inspect.cancel(args)
    end,
    {
      type = "object",
      properties = {
        runId = { type = "string", description = "ID do run" },
      },
      required = { "runId" },
    }
  )
end

return M
