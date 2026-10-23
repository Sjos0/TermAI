-- tools/subagents/cleanup.lua — Retenção dos runs já anunciados (issue #94).
-- cleanup = "keep": nunca apaga. cleanup = "delete": apaga logo após o anúncio (explícito).
-- Padrão ("retain"): guarda os RETAIN_MAX mais recentes e apaga o que passar de RETAIN_SECONDS.
local registry  = require("tools.subagents.registry")
local scheduler = require("tools.subagents.scheduler")
local log       = require("diag.log")
local M = {}

M.RETAIN_MAX     = 50
M.RETAIN_SECONDS = 7 * 24 * 3600

local function remove(rec, why)
  registry.remove(rec.runId)
  log.info("cleanup_removed", { run_id = rec.runId, reason = why })
end

-- now é injetável nos testes. Devolve quantos runs foram removidos.
function M.sweep(now)
  now = now or os.time()
  local retained, n = {}, 0
  for _, rec in ipairs(registry.list()) do
    if scheduler.is_terminal(rec) and rec.announce_consumed and rec.cleanup ~= "keep" then
      if rec.cleanup == "delete" then
        remove(rec, "delete")
        n = n + 1
      else
        retained[#retained + 1] = rec
      end
    end
  end
  table.sort(retained, function(a, b)
    return (a.announced_at or a.finished_at or 0) > (b.announced_at or b.finished_at or 0)
  end)
  for i, rec in ipairs(retained) do
    local when = rec.announced_at or rec.finished_at or now
    if i > M.RETAIN_MAX then
      remove(rec, "limite de " .. M.RETAIN_MAX .. " runs"); n = n + 1
    elseif now - when > M.RETAIN_SECONDS then
      remove(rec, "mais de 7 dias"); n = n + 1
    end
  end
  return n
end

return M
