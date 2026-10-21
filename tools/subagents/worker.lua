-- tools/subagents/worker.lua — Processo filho: roda o run em um turno e grava resultado e status.
local registry = require("tools.subagents.registry")
local events   = require("tools.subagents.events")
local M = {}

local function finish(run_id, status, err)
  local cur = registry.load(run_id) or { runId = run_id }
  if cur.status == "killed" or cur.status == "timeout" then return end
  cur.status, cur.error, cur.finished_at = status, err, os.time()
  registry.save(cur)
end

-- Sai com código 0 se concluiu, 1 se falhou.
function M.run(run_id)
  local rec = registry.load(run_id)
  if not rec then
    io.stderr:write("run não encontrado: " .. tostring(run_id) .. "\n")
    os.exit(1)
  end

  local ok, err = pcall(function()
    local context = require("agent.context")
    local loop    = require("agent.loop")
    local ctx = context.build({ agent_id = rec.agentId, model = rec.model,
                                is_subagent = true, run_id = run_id })
    events.append(run_id, "start", rec.task)
    local resp, _, _, overflow = loop.rodar(ctx, rec.task, "user", ctx.MAX_ITER)
    if overflow then error("contexto estourou") end
    local text = tostring(resp or "")
    if text == "" then error("resposta final vazia") end
    registry.write_result(run_id, text)
  end)

  if ok then
    finish(run_id, "completed", nil)
    events.append(run_id, "final", "ok")
    os.exit(0)
  end
  finish(run_id, "failed", tostring(err))
  events.append(run_id, "final", "falha: " .. tostring(err))
  os.exit(1)
end

return M
