-- tools/subagents/policy.lua — allowAgents, caps e denylist de tools para filhos.
local config = require("config")
local M = {}

M.CHILD_DENYLIST = {
  "sessions_spawn",
  "sessoes_listar",
  "sessoes_historico",
  "sessao_status",
  "subagents_listar",
  "subagents_status",
  "subagents_wait",
  "subagents_cancel",
}

local function defaults_subagents(cfg)
  cfg = cfg or config.load()
  local d = (cfg.agents and cfg.agents.defaults and cfg.agents.defaults.subagents) or {}
  return {
    maxConcurrent       = tonumber(d.maxConcurrent) or 2,
    maxChildrenPerAgent = tonumber(d.maxChildrenPerAgent) or 3,
    maxSpawnDepth       = tonumber(d.maxSpawnDepth) or 1,
    model               = d.model,
    runTimeoutSeconds   = tonumber(d.runTimeoutSeconds) or 300,
    allowAgents         = d.allowAgents,
  }
end

M.defaults = defaults_subagents

function M.is_agent_allowed(requester_id, target_id, cfg)
  if not target_id or target_id == "" then return false, "agentId vazio" end
  if target_id == requester_id then return true end

  local entry = config.get_agent(requester_id)
  local allow = (entry and entry.subagents and entry.subagents.allowAgents)
    or defaults_subagents(cfg).allowAgents

  if type(allow) ~= "table" then
    return false, "policy: agentId '" .. target_id .. "' não permitido (allowAgents não configurado; default = só o próprio id)"
  end
  for _, id in ipairs(allow) do
    if id == "*" or id == target_id then return true end
  end
  return false, "policy: agentId '" .. target_id .. "' fora de allowAgents"
end

function M.check_caps(requester_id, cfg)
  local d = defaults_subagents(cfg)
  local store = require("tools.subagents.store")
  local concurrent = store.count_active(nil)
  if concurrent >= d.maxConcurrent then
    return false, "policy: maxConcurrent=" .. d.maxConcurrent .. " atingido (" .. concurrent .. " ativos)"
  end
  local per_agent = store.count_active(requester_id)
  if per_agent >= d.maxChildrenPerAgent then
    return false, "policy: maxChildrenPerAgent=" .. d.maxChildrenPerAgent
      .. " atingido para requester '" .. tostring(requester_id) .. "'"
  end
  return true, d
end

function M.child_disabled_set(target_agent_id)
  local set = {}
  for _, name in ipairs(M.CHILD_DENYLIST) do
    set[name] = true
  end
  local entry = config.get_agent(target_agent_id)
  local list = (entry and entry.disabled_tools) or {}
  for _, name in ipairs(list) do
    if type(name) == "string" then set[name] = true end
  end
  return set
end

function M.resolve_model(spawn_model, target_agent_id, cfg)
  cfg = cfg or config.load()
  if spawn_model and spawn_model ~= "" then return spawn_model end
  local entry = config.get_agent(target_agent_id)
  if entry and entry.model then
    if type(entry.model) == "table" and entry.model.primary and entry.model.primary ~= "" then
      return entry.model.primary
    elseif type(entry.model) == "string" and entry.model ~= "" then
      return entry.model
    end
  end
  local d = defaults_subagents(cfg)
  if d.model and d.model ~= "" then return d.model end
  local primary = cfg.agents and cfg.agents.defaults and cfg.agents.defaults.model
    and cfg.agents.defaults.model.primary
  return primary or ""
end

return M
