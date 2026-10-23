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
function M.has_pending(ctx)
  if not ctx then return false end
  for _, r in ipairs(registry.list()) do
    if scheduler.is_terminal(r) and not r.announce_consumed and (r.parent_agent or "main") == (ctx.agent_id or "main") then
      return true
    end
  end
  return false
end

function M.register(tools)
  tools_def.register(tools, function() return bound_ctx end)
end

-- Ponto seguro do pai: avança a fila, entrega resultados e limpa runs entregues.
function M.on_boundary(ctx)
  if not ctx then return end
  if ctx.is_subagent then
    pcall(snapshot.tick, ctx)
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
