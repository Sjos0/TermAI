-- context.lua — Inicialização e construção do ctx.
-- Lê configurações de request (timeout, retries) e as aplica no api.lua.
local config_mod    = require("config")
local models_mod    = require("models")
local security      = require("agent.security")
local api           = require("agent.api")
local prompt_module = require("prompt")
local tools         = require("tools")
local session       = require("session")
local mf            = require("memoryflush")

local M = {}

local HOME      = os.getenv("HOME") or "/data/data/com.termux/files/home"
local workspace = HOME .. "/.TermAI/workspace"

function M.build()
  local cfg = config_mod.load()
  models_mod.load()

  local active = models_mod.resolve(cfg.agents.defaults.model.primary)
  if not active then
    print("[ERRO] Modelo ativo não encontrado: "
      .. tostring(cfg.agents.defaults.model.primary))
    os.exit(1)
  end

  security.validate(active.endpoint, active.api_key)

  -- ── Configurações de requisição ────────────────────────────────────────
  local req = cfg.agents.defaults.request or {}
  if req.timeout    then api.CURL_TIMEOUT = req.timeout    end
  if req.max_retries then api.MAX_RETRIES = req.max_retries end
  if req.retry_mode  then api.RETRY_MODE  = req.retry_mode  end
  if req.retry_static then api.RETRY_STATIC = req.retry_static end
  if req.retry_max    then api.RETRY_MAX    = req.retry_max    end

  local session_cfg = cfg.agents.defaults.session or {}
  local reset_info  = session.init(session_cfg)

  local compaction = cfg.agents.defaults.compaction or {}

  local ctx = {
    cfg        = cfg,
    active     = active,
    tokens     = 0,
    msgs       = {{role = "system",
                   content = prompt_module.build(workspace, tools, session.current(), cfg)}},
    MAX_ITER   = cfg.agents.defaults.maxIter or 20,
    workspace  = workspace,
    compaction = compaction,
  }

  session.set_model(active.ref)

  local agent_id   = (cfg.agents.list and cfg.agents.list[1] and
                      cfg.agents.list[1].id) or "main"
  local agent_base = HOME .. "/.TermAI/agents/" .. agent_id
  mf.init(agent_base, agent_id)

  return ctx, reset_info
end

return M
