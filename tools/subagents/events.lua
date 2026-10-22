-- tools/subagents/events.lua — Log de eventos por run (events.jsonl), lido por subagents_log.
local json     = require("json")
local registry = require("tools.subagents.registry")
local M = {}

function M.append(run_id, kind, text)
  local f = io.open(registry.dir(run_id) .. "/events.jsonl", "a")
  if not f then return false end
  f:write(json.encode({ t = os.time(), kind = kind, text = tostring(text or "") }) .. "\n")
  f:close()
  return true
end

-- Registra no run do filho cada tentativa de requisição que falhou (o pai não grava nada).
function M.retry(ctx, attempt, max, err, wait)
  if not (ctx and ctx.is_subagent and ctx.run_id) then return false end
  return M.append(ctx.run_id, "retry", string.format("tentativa %d/%d falhou: %s (próxima em %ds)",
    attempt, max, tostring(err), wait or 0))
end

-- Últimas n linhas do log (padrão 20).
function M.tail(run_id, n)
  local lines = {}
  local f = io.open(registry.dir(run_id) .. "/events.jsonl", "r")
  if not f then return lines end
  for line in f:lines() do lines[#lines + 1] = line end
  f:close()
  local out = {}
  for i = math.max(1, #lines - (n or 20) + 1), #lines do out[#out + 1] = lines[i] end
  return out
end

return M
