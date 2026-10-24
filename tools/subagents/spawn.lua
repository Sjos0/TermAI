-- tools/subagents/spawn.lua — sessions_spawn: cria um run (clone ou agente independente) e responde na hora.
local registry  = require("tools.subagents.registry")
local scheduler = require("tools.subagents.scheduler")
local config    = require("config")
local json      = require("json")
local log       = require("diag.log")
local M = {}

-- args: task, agentId, label, model, cleanup ("delete"|"keep"), runTimeoutSeconds
-- Pode o agente/run de profundidade parent_depth criar um filho? (regra pura, testável)
function M.can_nest(parent_depth, max_depth)
  return (tonumber(parent_depth) or 0) + 1 <= (tonumber(max_depth) or 1)
end

function M.spawn(args, parent)
  args = type(args) == "table" and args or {}
  if type(args.task) ~= "string" or args.task:match("^%s*$") then
    return "❌ sessions_spawn: 'task' (string) é obrigatório."
  end
  if not parent then return "❌ sessions_spawn: nenhum agente ativo." end
  local max_depth = scheduler.limits(parent.cfg or require("config").load()).maxSpawnDepth
  -- Subagente sem profundidade explícita conta como nível 1 (nunca como agente principal).
  local parent_depth = parent.depth or (parent.is_subagent and 1 or 0)
  if not M.can_nest(parent_depth, max_depth) then
    return string.format("❌ sessions_spawn: profundidade máxima atingida (maxSpawnDepth=%d).", max_depth)
  end

  local cfg      = parent.cfg or config.load()
  local lim      = scheduler.limits(cfg)
  local agent_id = parent.agent_id or "main"
  local kind     = "clone"
  if type(args.agentId) == "string" and args.agentId ~= "" and args.agentId ~= agent_id then
    if not config.get_agent(args.agentId) then
      return "❌ sessions_spawn: agente '" .. args.agentId .. "' não existe em agents.list."
    end
    agent_id, kind = args.agentId, "agente"
  end

  local rec = {
    runId            = registry.new_id(),
    kind             = kind,
    agentId          = agent_id,
    task             = args.task,
    label            = args.label,
    model            = args.model,
    cleanup          = args.cleanup == "keep" and "keep" or (args.cleanup == "delete" and "delete" or "retain"),
    timeout_seconds  = tonumber(args.runTimeoutSeconds) or lim.runTimeoutSeconds,
    status           = "queued",
    created_at       = os.time(),
    parent_agent     = parent.agent_id or "main",
    parent_run       = parent.run_id,
    origin           = args.origin or "agent",
    depth            = parent_depth + 1,
    announce_pending = false,
    announce_consumed = false,
  }
  local ok, err = scheduler.admit(rec, cfg)
  if not ok then return "❌ sessions_spawn: " .. tostring(err) end

  log.info("spawn_accepted", { run_id = rec.runId, kind = kind, agent = agent_id,
    task_chars = #args.task, cleanup = rec.cleanup })
  scheduler.tick(cfg)
  local fresh = registry.load(rec.runId) or rec
  return json.encode({ status = "accepted", runId = rec.runId, agentId = agent_id,
                       kind = kind, state = fresh.status })
end

return M
