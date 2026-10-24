-- tools/subagents.lua — Fachada do sistema de subagentes (processos em background).
local tools_def = require("tools.subagents.tools_def")
local scheduler = require("tools.subagents.scheduler")
local announce  = require("tools.subagents.announce")
local cleanup   = require("tools.subagents.cleanup")
local registry  = require("tools.subagents.registry")

local M = {}
local snapshot = require("tools.subagents.snapshot")
local bound_ctx = nil

-- Guarda o contexto do agente que está rodando o turno.
function M.bind(ctx) bound_ctx = ctx end
function M.current() return bound_ctx end

-- Há resultado terminado ainda não entregue a este pai? (acorda o orquestrador quando ocioso)
-- Acorda o pai quando há término não entregue. Agrupa avisos: espera 5 s após o primeiro término,
-- ou até os filhos ativos acabarem, para não gerar um turno do modelo por filho.
function M.has_pending(ctx)
  if not ctx then return false end
  local owner, oldest, active = ctx.agent_id or "main", nil, 0
  for _, r in ipairs(registry.list()) do
    if (r.parent_agent or "main") == owner then
      if scheduler.is_terminal(r) then
        if not r.announce_consumed then
          local t = r.finished_at or os.time()
          if not oldest or t < oldest then oldest = t end
        end
      else
        active = active + 1
      end
    end
  end
  if not oldest then return false end
  return active == 0 or (os.time() - oldest) >= 5
end

-- Quantos subagentes deste agente ainda estão ativos (usado ao sair da TUI).
function M.active_count(ctx)
  local owner, n = (ctx and ctx.agent_id) or "main", 0
  for _, r in ipairs(registry.list()) do
    if (r.parent_agent or "main") == owner and not scheduler.is_terminal(r) then n = n + 1 end
  end
  return n
end

function M.register(tools)
  tools_def.register(tools, function() return bound_ctx end)
  require("tools.subagents.send_def").register(tools, function() return bound_ctx end)
end

-- Ponto seguro do pai: avança a fila, entrega resultados e limpa runs entregues.
function M.on_boundary(ctx)
  if not ctx then return end
  if ctx.is_subagent then
    pcall(snapshot.tick, ctx)
    pcall(require("tools.subagents.inbox").deliver, ctx)
    pcall(require("tools.subagents.announce").inject, ctx)
    return
  end
  local ok, err = pcall(function()
    scheduler.tick(ctx.cfg)
    announce.inject(ctx)
    cleanup.sweep()
  end)
  if not ok then io.stderr:write("[subagentes] " .. tostring(err) .. "\n") end
end

return M
