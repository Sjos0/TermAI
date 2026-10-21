-- tools/subagents/child_ctx.lua — Monta o contexto efêmero do clone a partir do pai.
local config = require("config")
-- prompt e tools são carregados sob demanda: tools.lua importa esta cadeia (evita ciclo).

local M = {}
local MAX_CLONE_ITER = 8

-- Tools que o clone não pode usar: sessions_spawn (profundidade 1) e as do próprio entry.
local function disabled_for(agent_id)
  local set = { sessions_spawn = true }
  local entry = config.get_agent(agent_id)
  for _, name in ipairs((entry and entry.disabled_tools) or {}) do
    if type(name) == "string" then set[name] = true end
  end
  return set
end

-- Retorna o contexto do clone. Nada aqui é gravado em disco.
function M.build(parent)
  local prompt = require("prompt")
  local tools  = require("tools")
  local cfg = parent.cfg or config.load()
  local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
  local workspace = parent.workspace or (HOME .. "/.TermAI/workspace")

  local parent_iter = tonumber(parent.MAX_ITER) or 0
  local max_iter = (parent_iter > 0 and parent_iter < MAX_CLONE_ITER) and parent_iter or MAX_CLONE_ITER

  return {
    cfg            = cfg,
    active         = parent.active,
    tokens         = 0,
    msgs           = { { role = "system", content = prompt.build(workspace, tools, "subagent", cfg) } },
    MAX_ITER       = max_iter,
    workspace      = workspace,
    compaction     = parent.compaction,
    agent_id       = parent.agent_id,
    disabled_tools = disabled_for(parent.agent_id),
    is_subagent    = true,
  }
end

return M
