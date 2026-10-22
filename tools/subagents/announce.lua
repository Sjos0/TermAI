-- tools/subagents/announce.lua — Entrega ao pai o resultado de cada run terminado (uma vez).
local registry  = require("tools.subagents.registry")
local scheduler = require("tools.subagents.scheduler")
local log       = require("diag.log")
local M = {}

local function body(rec)
  if rec.status == "completed" then return registry.read_result(rec.runId) or "" end
  local out = "erro: " .. tostring(rec.error or rec.status)
  local partial = rec.partial and registry.read_result(rec.runId) or ""
  if partial ~= "" then out = out .. "\n[resultado parcial, incompleto]\n" .. partial end
  return out .. "\nO trabalho do subagente NÃO foi concluído. Decida: tentar de novo (no máximo uma vez), assumir a tarefa você mesmo ou avisar o usuário."
end

-- Injeta no contexto do pai as respostas finais. A TUI só mostra uma linha de status.
function M.inject(ctx)
  if not ctx or not ctx.msgs then return 0 end
  local n = 0
  for _, rec in ipairs(registry.list()) do
    if scheduler.is_terminal(rec) and not rec.announce_consumed and rec.parent_agent == ctx.agent_id then
      ctx.msgs[#ctx.msgs + 1] = {
        role = "system",
        content = string.format("[subagente %s status=%s agente=%s]\n%s",
          rec.runId, rec.status, tostring(rec.agentId), body(rec)),
      }
      io.write(require("ui.subagent_block").end_line(rec), "\n")
      rec.announce_consumed, rec.announce_pending = true, false
      log.info("announce_delivered", { run_id = rec.runId, status = rec.status,
        result_chars = #body(rec) })
      registry.save(rec)
      n = n + 1
    end
  end
  io.flush()
  return n
end

return M
