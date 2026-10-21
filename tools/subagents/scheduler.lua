-- tools/subagents/scheduler.lua — Fila, admissão e ciclo de vida dos runs (um processo por run).
local registry = require("tools.subagents.registry")
local launcher = require("tools.subagents.launcher")
local M = {}

local TERMINAL = { completed = true, failed = true, killed = true, timeout = true }

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
local function finish(run_id, status, err)
  local cur = registry.load(run_id)
  if not cur or M.is_terminal(cur) then return end
  cur.status, cur.error, cur.finished_at = status, err, os.time()
  cur.announce_pending = true
  registry.save(cur)
end

local function timed_out(r, lim)
  local limit = tonumber(r.timeout_seconds) or lim.runTimeoutSeconds
  return r.started_at and (os.time() - r.started_at) >= limit
end

-- Reconcilia processos, aplica timeouts e inicia runs da fila até o limite de simultâneos.
function M.tick(cfg)
  local lim = M.limits(cfg)
  for _, r in ipairs(registry.list()) do
    if r.status == "running" then
      if timed_out(r, lim) then
        launcher.kill(r.pid)
        finish(r.runId, "timeout", "runTimeoutSeconds excedido")
      elseif not launcher.alive(r.pid) then
        finish(r.runId, "failed", "process_exit")
      end
    end
  end

  local runs = registry.list()
  local running = count(runs, function(r) return r.status == "running" end)
  for _, r in ipairs(runs) do
    if running >= lim.maxConcurrent then break end
    if r.status == "queued" then
      local pid = launcher.start(r.runId)
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
