-- tools/subagents/launcher.lua — Sobe e controla o processo de um subagente (processo do sistema).
local registry = require("tools.subagents.registry")
local log      = require("diag.log")
local M = {}

-- Injetável nos testes: troca os comandos do sistema por simulações.
M.exec = {
  popen   = function(cmd) return io.popen(cmd) end,
  execute = function(cmd) return os.execute(cmd) end,
}

-- Inicia "TermAI run --worker <run_id>" em segundo plano e devolve o pid.
function M.start(run_id)
  local interp = (arg and arg[-1]) or "lua5.4"
  local script = (os.getenv("HOME") or "") .. "/TermAI/main.lua"
  local errlog = registry.dir(run_id) .. "/stderr.log"
  local outlog = registry.dir(run_id) .. "/stdout.log"
  local cmd = string.format("'%s' '%s' run --worker '%s' >>'%s' 2>>'%s' & echo $!",
    interp, script, run_id, outlog, errlog)
  local h = M.exec.popen(cmd)
  if not h then
    log.error("launcher_popen_failed", { run_id = run_id })
    return nil
  end
  local out = h:read("*a") or ""
  h:close()
  local pid = tonumber(out:match("(%d+)"))
  log.info("launcher_start", { run_id = run_id, child_pid = pid })
  return pid
end

function M.alive(pid)
  if not pid then return false end
  return M.exec.execute(string.format("kill -0 %d 2>/dev/null", pid)) == true
end

function M.kill(pid)
  if not pid then return end
  M.exec.execute(string.format("kill -TERM %d 2>/dev/null", pid))
  log.info("launcher_kill", { child_pid = pid })
end

return M
