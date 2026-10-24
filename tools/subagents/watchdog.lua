-- tools/subagents/watchdog.lua — Vigia do filho: se a TUI que o criou morreu (ex.: Ctrl+C mata o
-- processo), o filho encerra sozinho, com o trabalho parcial salvo. Sem isso, ele ficaria órfão,
-- gastando bateria e tokens sem ninguém ver. Chamado no ponto seguro do filho (entre turnos).
local registry = require("tools.subagents.registry")
local M = {}

-- Injetáveis nos testes: nunca matam processo real.
M.alive = function(pid) return os.execute(string.format("kill -0 %d 2>/dev/null", pid)) == true end
M.exit  = function(code) os.exit(code) end

-- Devolve true se o dono sumiu e o filho foi encerrado (o processo sai logo depois).
function M.check(run_id)
  local r = registry.load(run_id)
  if not r or not r.owner_pid then return false end
  if M.alive(r.owner_pid) then return false end
  r.status, r.error, r.finished_at = "killed", "TUI encerrada; trabalho parcial salvo", os.time()
  r.announce_pending = true
  if registry.promote_partial(run_id) then r.partial = true end
  registry.save(r)
  M.exit(1)
  return true
end

return M
