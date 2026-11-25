-- context.lua — Inicialização e construção do ctx.
-- Lê configurações de request (timeout, retries) e as aplica no api.lua.
-- v2: popula ctx.disabled_tools a partir do agente ativo (Issue #32).
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

function M.build(opts)
  opts = opts or {}
  local cfg = config_mod.load()
  models_mod.load()

  local resolve_model_ref = require("agent.resolve_model_ref")
  local active_ref, model_source, model_fallbacks = resolve_model_ref.resolve(opts, cfg, function(ref)
    return models_mod.resolve(ref) ~= nil
  end)
  local active = active_ref and models_mod.resolve(active_ref) or nil
  if not active then
    print("\27[38;5;220m[WARN] Nenhum modelo configurado ainda.\27[0m")
    print("Rode primeiro:  \27[1mTermAI models add-provider\27[0m")
    print("Depois defina:  \27[1mTermAI models set <provider>/<modelo>\27[0m")
    os.exit(1)
  end

  -- Ciclo de topo no boot: testa anteriores (orcamento + progresso em TTY).
  if not opts.is_subagent then
    local function is_tty()
      local ok, r = pcall(function()
        return io.type(io.stdout) == "file" and io.stdout.isatty and io.stdout:isatty()
      end)
      return ok and r == true
    end
    local tty = is_tty()
    local recovered, recovered_index = models_mod.prefer_top_api_key_on_boot(
      active.ref, {
        connect_timeout = 1, max_time = 3, speed_time = 2,
        max_previous = 3, max_wall_seconds = 9,
        on_progress = tty and function(event, payload)
          if event == "start" then
            io.write(string.format(
              "[KEY] Verificando chaves 1..%d (ativa %d)...\n",
              payload.to, payload.current))
            io.flush()
          elseif event == "probe" then
            io.write(string.format(
              "[KEY] Probe %d/%d...\n", payload.index, payload.total))
            io.flush()
          elseif event == "budget" then
            io.write("[KEY] Orçamento de boot esgotado; mantendo chave ativa.\n")
            io.flush()
          end
        end or nil,
      })
    if recovered then
      active = models_mod.resolve(active.ref)
      if tty then
        io.write(string.format(
          "[KEY] Chave do topo recuperada: %d/%d.\n",
          recovered_index, active.api_key_count))
        io.flush()
      end
    end
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

  -- Agente ativo: mesmo critério já usado no projeto (primeiro da lista ou id).
  -- Nunca hardcodar "main" no path de filtro (Issue #32).
  local agent_id = opts.agent_id or (cfg.agents.list and cfg.agents.list[1] and
                    cfg.agents.list[1].id) or "main"
  local agent_entry = config_mod.get_agent(agent_id)
  local disabled_list = (agent_entry and agent_entry.disabled_tools) or {}
  -- Workspace do agente: caminho relativo a ~/.TermAI (igual ao "workspace" do main).
  local ws = workspace
  if agent_entry and type(agent_entry.workspace) == "string" and agent_entry.workspace ~= "" then
    ws = agent_entry.workspace:sub(1, 1) == "/" and agent_entry.workspace
         or (HOME .. "/.TermAI/" .. agent_entry.workspace)
  end
  -- Subagente (processo filho): sem criar outros subagentes nem agentes.
  if opts.is_subagent then
    local merged = {}
    for _, name in ipairs(disabled_list) do merged[#merged + 1] = name end
    merged[#merged + 1] = "sessions_spawn"
    merged[#merged + 1] = "agents_create"
    disabled_list = merged
  end
  local disabled_set = {}
  for _, name in ipairs(disabled_list) do
    if type(name) == "string" then disabled_set[name] = true end
  end

  local ctx = {
    cfg             = cfg,
    active          = active,
    tokens          = 0,
    msgs            = {{role = "system",
                       content = prompt_module.build(ws, tools, session.current(), cfg)}},
    MAX_ITER        = cfg.agents.defaults.maxIter or 20,
    workspace       = opts.workspace or ws,
    compaction      = compaction,
    agent_id        = agent_id,
    disabled_tools  = disabled_set,
    is_subagent     = opts.is_subagent == true,
    run_id          = opts.run_id,
    model_source    = model_source,
    model_fallbacks = model_fallbacks,
  }

  session.set_model(active.ref)

  -- Subagente é efêmero: não inicializa memória de longo prazo.
  if not opts.is_subagent then
    mf.init(HOME .. "/.TermAI/agents/" .. agent_id, agent_id)
  end

  return ctx, reset_info
end

return M
