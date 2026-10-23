-- tools/subagents/worker.lua — Processo filho: roda o run em um turno e grava resultado e status.
local registry = require("tools.subagents.registry")
local events   = require("tools.subagents.events")
local error_class = require("tools.subagents.error_class")
local log      = require("diag.log")
local M = {}

local function finish(run_id, status, err, extra)
  local cur = registry.load(run_id) or { runId = run_id }
  if cur.status == "killed" or cur.status == "timeout" then return end
  cur.status, cur.error, cur.finished_at = status, err, os.time()
  for k, v in pairs(extra or {}) do cur[k] = v end
  registry.save(cur)
end

-- Classifica a saída final do loop. Devolve o texto, ou nil + motivo (+ texto parcial).
-- "[ERRO...]" é a requisição que esgotou as tentativas do usuário, não uma resposta do modelo.
local function classify(resp, overflow, complete)
  if overflow then return nil, "contexto estourou" end
  local text = tostring(resp or "")
  if text:match("^%[ERRO") then return nil, text:sub(1, 500) end
  if text == "" then return nil, "resposta final vazia (limite de iterações ou modelo sem resposta)" end
  if complete == false then return nil, "resposta incompleta (stream cortado)", text end
  return text
end

-- Executa o run e grava result.txt e status. Retorna ok, erro. Não sai do processo.
function M.execute(run_id)
  local rec = registry.load(run_id)
  if not rec then return false, "run não encontrado: " .. tostring(run_id) end
  local t0 = os.time()
  log.info("worker_start", { run_id = run_id, agent = rec.agentId, kind = rec.kind,
    model = rec.model or "default", rss_kb = log.rss_kb() })

  local partial = false
  local run_usage = nil
  local ok, err = pcall(function()
    local context = require("agent.context")
    local loop    = require("agent.loop")
    local ctx = context.build({ agent_id = rec.agentId, model = rec.model,
                                is_subagent = true, run_id = run_id })
    events.append(run_id, "start", rec.task)
    local resp, _, _, overflow, complete = loop.rodar(ctx, rec.task, "user", ctx.MAX_ITER)
    run_usage = ctx.usage_acc
    local text, reason, part = classify(resp, overflow, complete)
    if not text then
      if part then registry.write_result(run_id, part); partial = true end
      error(reason, 0)
    end
    registry.write_result(run_id, text)
  end)

  local elapsed = os.time() - t0
  if ok then
    finish(run_id, "completed", nil, { usage = run_usage })
    events.append(run_id, "final", "ok")
    log.info("worker_end", { run_id = run_id, status = "completed", duration_s = elapsed,
      result_chars = #(registry.read_result(run_id) or ""), rss_kb = log.rss_kb() })
    return true
  end
  local extra = { error_class = error_class.of(tostring(err)) }
  if partial then extra.partial = true end
  extra.usage = run_usage
  finish(run_id, "failed", tostring(err), extra)
  events.append(run_id, "final", "falha: " .. tostring(err))
  log.error("worker_end", { run_id = run_id, status = "failed", duration_s = elapsed,
    reason = tostring(err), partial = partial, rss_kb = log.rss_kb() })
  return false, tostring(err)
end

-- Entrada do processo filho (TermAI run --worker <run_id>): código 0 ok, 1 falha.
function M.run(run_id)
  local ok, err = M.execute(run_id)
  if not ok then io.stderr:write(tostring(err) .. "\n") end
  os.exit(ok and 0 or 1)
end

return M
