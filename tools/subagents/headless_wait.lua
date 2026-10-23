-- tools/subagents/headless_wait.lua — Espera dos filhos numa execução headless (issue #92).
-- Sem TUI não há aviso automático: TermAI run --wait-subagents[=N] espera os filhos do pai,
-- imprime os resultados e sai. Padrão: desligado. Teto: 900 s.
local registry  = require("tools.subagents.registry")
local scheduler = require("tools.subagents.scheduler")
local announce  = require("tools.subagents.announce")
local M = {}

M.MAX_SECONDS = 900
M.tick  = function(cfg) return scheduler.tick(cfg) end        -- injetável nos testes
M.sleep = function(s) os.execute("sleep " .. tostring(s)) end -- injetável nos testes
M.now   = function() return os.time() end                     -- injetável nos testes

local function children(parent, only_active)
  local out = {}
  for _, r in ipairs(registry.list()) do
    if (r.parent_agent or "main") == parent then
      if not only_active or not scheduler.is_terminal(r) then out[#out + 1] = r end
    end
  end
  return out
end

-- Espera os filhos ativos do pai. Devolve "ok" (nenhum ativo) ou "timeout" e a lista pendente.
function M.run(cfg, parent, seconds)
  seconds = math.min(tonumber(seconds) or 0, M.MAX_SECONDS)
  local deadline = M.now() + seconds
  while true do
    M.tick(cfg)
    local pending = children(parent, true)
    if #pending == 0 then return "ok", {} end
    if M.now() >= deadline then return "timeout", pending end
    M.sleep(1)
  end
end

-- Resumo de cada filho terminado do pai ainda não entregue. Marca como entregue.
function M.print_results(parent)
  local out = {}
  for _, r in ipairs(children(parent, false)) do
    if scheduler.is_terminal(r) and not r.announce_consumed then
      out[#out + 1] = announce.summary(r)
      r.announce_consumed, r.announce_pending = true, false
      r.announced_at = M.now()
      registry.save(r)
    end
  end
  return out
end

return M
