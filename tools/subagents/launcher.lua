-- tools/subagents/launcher.lua — Sobe e controla o processo de um subagente (processo do sistema).
local registry = require("tools.subagents.registry")
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
  local log    = registry.dir(run_id) .. "/stderr.log"
  local cmd = string.format("'%s' '%s' run --worker '%s' >/dev/null 2>>'%s' & echo $!",
    interp, script, run_id, log)
  local h = M.exec.popen(cmd)
  if not h then return nil end
  local out = h:read("*a") or ""
  h:close()
  return tonumber(out:match("(%d+)"))
end

function M.alive(pid)
  if not pid then return false end
  return M.exec.execute(string.format("kill -0 %d 2>/dev/null", pid)) == true
end

function M.kill(pid)
  if pid then M.exec.execute(string.format("kill -TERM %d 2>/dev/null", pid)) end
end

return M
