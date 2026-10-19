-- tools/subagents/spawn.lua — sessions_spawn: cria run isolado e retorna imediatamente.
local json   = require("json")
local store  = require("tools.subagents.store")
local policy = require("tools.subagents.policy")
local ids    = require("tools.subagents.ids")
local M = {}

local function now_iso()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

function M.spawn(args, parent_ctx)
  args = type(args) == "table" and args or {}
  local task = args.task
  if type(task) ~= "string" or task:match("^%s*$") then
    return "❌ sessions_spawn: parâmetro 'task' (string) é obrigatório."
  end

  local parent_id = (parent_ctx and parent_ctx.agent_id)
    or (parent_ctx and parent_ctx.cfg and parent_ctx.cfg.agents
        and parent_ctx.cfg.agents.list and parent_ctx.cfg.agents.list[1]
        and parent_ctx.cfg.agents.list[1].id)
    or "main"

  if parent_ctx and parent_ctx.is_subagent then
    return "❌ sessions_spawn: depth máximo=1; filho não pode spawnar."
  end

  local target_id = args.agentId or parent_id
  local cfg = parent_ctx and parent_ctx.cfg or nil

  local ok_allow, reason = policy.is_agent_allowed(parent_id, target_id, cfg)
  if not ok_allow then return "❌ " .. tostring(reason) end

  local ok_caps, caps_or_err = policy.check_caps(parent_id, cfg)
  if not ok_caps then return "❌ " .. tostring(caps_or_err) end
  local caps = caps_or_err

  local run_id = ids.run_id()
  local child_key = ids.child_session_key(target_id, run_id)
  local timeout = tonumber(args.runTimeoutSeconds) or caps.runTimeoutSeconds
  local model_ref = policy.resolve_model(args.model, target_id, cfg)

  local run = {
    runId            = run_id,
    childSessionKey  = child_key,
    agentId          = target_id,
    parent_agent_id  = parent_id,
    parent_session   = parent_ctx and parent_ctx.session_id or nil,
    task             = task,
    label            = args.label,
    model            = model_ref,
    status           = "queued",
    created_at       = now_iso(),
    created_at_unix  = os.time(),
    updated_at       = now_iso(),
    timeout_seconds  = timeout,
    result_text      = nil,
    error            = nil,
    finished_at      = nil,
    announce_pending = false,
    announce_consumed = false,
    context          = "isolated",
  }

  local path = ids.transcript_path(target_id, run_id)
  local f = io.open(path, "w")
  if f then
    f:write(json.encode({
      type = "session", version = 1,
      id = child_key, key = child_key,
      timestamp = now_iso(),
      parent_run = run_id,
    }) .. "\n")
    f:write(json.encode({
      type = "message", role = "user", content = task,
      timestamp = now_iso(),
    }) .. "\n")
    f:close()
  end
  run.transcript_path = path

  store.upsert(run)

  local payload = {
    runId = run_id,
    childSessionKey = child_key,
    status = run.status,
    agentId = target_id,
  }
  return json.encode(payload)
end

return M
