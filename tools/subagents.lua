-- tools/subagents.lua — Fachada do sistema de subagentes (processos em background).
local tools_def = require("tools.subagents.tools_def")
local scheduler = require("tools.subagents.scheduler")
local announce  = require("tools.subagents.announce")
local cleanup   = require("tools.subagents.cleanup")

local M = {}
local bound_ctx = nil

-- Guarda o contexto do agente que está rodando o turno.
function M.bind(ctx) bound_ctx = ctx end
function M.current() return bound_ctx end

function M.register(tools)
  tools_def.register(tools, function() return bound_ctx end)
end

-- Ponto seguro do pai: avança a fila, entrega resultados e limpa runs entregues.
function M.on_boundary(ctx)
  if not ctx or ctx.is_subagent then return end
  local ok, err = pcall(function()
    scheduler.tick(ctx.cfg)
    announce.inject(ctx)
    cleanup.sweep()
  end)
  if not ok then io.stderr:write("[subagentes] " .. tostring(err) .. "\n") end
end

return M
