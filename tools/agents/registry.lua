-- tools/agents/registry.lua — Registra o agente independente em agents.list do config.
local config = require("config")
local paths  = require("tools.agents.paths")
local M = {}

function M.exists(id)
  return config.get_agent(id) ~= nil
end

-- Adiciona a entrada em agents.list e salva. Retorna ok, erro.
-- disabled_tools: o agente independente não pode criar outros agentes.
function M.add(id, nome)
  if M.exists(id) then return false, "agente '" .. id .. "' já existe" end
  local list = config.get("agents.list") or {}
  list[#list + 1] = {
    id             = id,
    name           = nome or id,
    workspace      = paths.workspace_rel(id),
    model          = { primary = "" },
    disabled_tools = { "agents_create" },
  }
  if not config.set("agents.list", list) then
    return false, "falha ao salvar o config"
  end
  return true
end

return M
