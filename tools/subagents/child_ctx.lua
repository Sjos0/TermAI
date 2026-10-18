-- tools/subagents/child_ctx.lua — Constrói ctx isolado para child run.
local policy = require("tools.subagents.policy")
local M = {}

function M.build(run, parent_cfg)
  local models_mod = require("models")
  local prompt_module = require("prompt")
  local tools = require("tools")
  local config = require("config")

  local cfg = parent_cfg or config.load()
  local model_ref = run.model
  if not model_ref or model_ref == "" then
    model_ref = policy.resolve_model(nil, run.agentId, cfg)
  end
  local active = models_mod.resolve(model_ref)
  if not active then
    return nil, "modelo não resolvido: " .. tostring(model_ref)
  end

  local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
  local workspace = HOME .. "/.TermAI/workspace"
  local entry = config.get_agent(run.agentId)
  if entry and type(entry.workspace) == "string" and entry.workspace ~= "" then
    if entry.workspace:sub(1, 1) == "/" then
      workspace = entry.workspace
    else
      workspace = HOME .. "/.TermAI/" .. entry.workspace
    end
  end

  local disabled = policy.child_disabled_set(run.agentId)
  local system_content = prompt_module.build(workspace, tools, run.childSessionKey, cfg)
  local max_iter = (cfg.agents and cfg.agents.defaults and cfg.agents.defaults.maxIter) or 20

  return {
    cfg            = cfg,
    active         = active,
    tokens         = 0,
    msgs           = {
      { role = "system", content = system_content },
      { role = "user", content = run.task },
    },
    MAX_ITER       = math.min(max_iter, 8),
    workspace      = workspace,
    compaction     = (cfg.agents and cfg.agents.defaults and cfg.agents.defaults.compaction) or {},
    agent_id       = run.agentId,
    disabled_tools = disabled,
    is_subagent    = true,
    subagent_runId = run.runId,
    session_id     = run.childSessionKey,
  }
end

return M
