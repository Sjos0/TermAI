-- tools/subagents/scheduler.lua — Fila, admissão e ciclo de vida dos runs (um processo por run).
local registry = require("tools.subagents.registry")
local launcher = require("tools.subagents.launcher")
local log      = require("diag.log")
local M = {}

local TERMINAL = { completed = true, failed = true, killed = true, timeout = true }
local rss_logged_at = {}   -- runId -> último log de RSS (no máximo a cada 60 s)

function M.is_terminal(rec)
  return TERMINAL[rec.status] == true
end

-- Limites de agents.defaults.subagents. Padrão 5 para simultâneos e por pai.
function M.limits(cfg)
  local d = (cfg and cfg.agents and cfg.agents.defaults and cfg.agents.defaults.subagents) or {}
  return {
    maxConcurrent       = tonumber(d.maxConcurrent) or 5,
    maxChildrenPerAgent = tonumber(d.maxChildrenPerAgent) or 5,
    runTimeoutSeconds   = tonumber(d.runTimeoutSeconds) or 600,
    maxSpawnDepth       = tonumber(d.maxSpawnDepth) or 1,   -- 1 = subagente não cria subagente (padrão atual)
  }
end

local function count(list, pred)
  local n = 0
  for _, r in ipairs(list) do if pred(r) then n = n + 1 end end
  return n
end

-- Admite um run como queued. Recusa se o pai já tem o máximo de filhos ativos.
function M.admit(rec, cfg)
  local lim = M.limits(cfg)
  local active = count(registry.list(), function(r)
    return r.parent_agent == rec.parent_agent and (r.status == "queued" or r.status == "running")
  end)
  if active >= lim.maxChildrenPerAgent then
    return false, "maxChildrenPerAgent=" .. lim.maxChildrenPerAgent .. " atingido"
  end
  if not registry.save(rec) then return false, "falha ao gravar o run" end
  return true
end

-- Recarrega antes de gravar: o processo filho pode ter escrito o estado enquanto isso.
local function finish(run_id, status, err, extra)
  local cur = registry.load(run_id)
  if not cur or M.is_terminal(cur) then return end
  cur.status, cur.error, cur.finished_at = status, err, os.time()
  cur.announce_pending = true
  for k, v in pairs(extra or {}) do cur[k] = v end
  registry.save(cur)
  log.info("run_finish", { run_id = run_id, status = status, reason = err,
    duration_s = cur.started_at and (os.time() - cur.started_at) or nil })
end

local function timed_out(r, lim)
  local limit = tonumber(r.timeout_seconds) or lim.runTimeoutSeconds
  return r.started_at and (os.time() - r.started_at) >= limit
end

-- Reconcilia processos, aplica timeouts e inicia runs da fila até o limite de simultâneos.
-- Filhos ativos de um run, em todos os níveis (netos incluídos). Ciclo é cortado por "visto".
local function active_descendants(run_id)
  local all, out, seen = registry.list(), {}, { [run_id] = true }
  local frontier = { run_id }
  while #frontier > 0 do
    local nxt = {}
    for _, cur in ipairs(frontier) do
      for _, r in ipairs(all) do
        if r.parent_run == cur and not seen[r.runId] then
          seen[r.runId] = true
          nxt[#nxt + 1] = r.runId
          if not M.is_terminal(r) then out[#out + 1] = r end
        end
      end
    end
    frontier = nxt
  end
  return out
end

-- Encerra a árvore de filhos ativos de um run. Usado por matar e quando o pai termina.
function M.stop_tree(run_id, reason)
  local n = 0
  for _, r in ipairs(active_descendants(run_id)) do
    launcher.kill(r.pid, r.runId)
    r.status, r.error, r.finished_at = "killed", reason or "pai encerrado", os.time()
    r.announce_pending = true
    registry.save(r)
    n = n + 1
  end
  return n
end

-- Filho ativo cujo pai já terminou não pode ficar órfão rodando: encerra a árvore do pai.
function M.cascade_orphans()
  for _, r in ipairs(registry.list()) do
    if r.parent_run and not M.is_terminal(r) then
      local parent = registry.load(r.parent_run)
      if parent and M.is_terminal(parent) then M.stop_tree(parent.runId, "pai encerrou") end
    end
  end
end

function M.tick(cfg)
  M.cascade_orphans()
  local lim = M.limits(cfg)
  for _, r in ipairs(registry.list()) do
    if r.status == "running" then
      local now_s = os.time()
      if (rss_logged_at[r.runId] or 0) + 60 <= now_s then
        rss_logged_at[r.runId] = now_s
        log.info("run_rss", { run_id = r.runId, child_pid = r.pid, child_rss_kb = log.rss_kb(r.pid) })
      end
      if timed_out(r, lim) then
        launcher.kill(r.pid, r.runId)
        local salvaged = registry.promote_partial(r.runId)
        finish(r.runId, "timeout", "runTimeoutSeconds excedido", { error_class = "timeout", partial = salvaged or nil })
      elseif not launcher.alive(r.pid, r.runId) then
        local salvaged = registry.promote_partial(r.runId)
        finish(r.runId, "failed", "process_exit", { error_class = "killed", partial = salvaged or nil })
      end
    end
  end

  local runs = registry.list()
  local running = count(runs, function(r) return r.status == "running" end)
  for _, r in ipairs(runs) do
    if running >= lim.maxConcurrent then break end
    if r.status == "queued" then
      local pid = launcher.start(r.runId, tonumber(r.timeout_seconds) or lim.runTimeoutSeconds)
      local cur = registry.load(r.runId)
      if cur and cur.status == "queued" then
        if pid then
          cur.status, cur.pid, cur.started_at = "running", pid, os.time()
          registry.save(cur)
          running = running + 1
        else
          finish(r.runId, "failed", "falha ao iniciar processo")
        end
      end
    end
  end
end

return M
