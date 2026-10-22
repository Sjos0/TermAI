-- tools/subagents/launcher.lua — Sobe e controla o processo de um subagente (processo do sistema).
local registry = require("tools.subagents.registry")
local log      = require("diag.log")
local M = {}

-- Linha de comando de um pid: /proc primeiro, ps como alternativa. nil se não der para ler.
local function read_cmdline(pid)
  local f = io.open(string.format("/proc/%d/cmdline", pid), "r")
  if f then
    local s = f:read("*a") or ""
    f:close()
    if s ~= "" then return (s:gsub("%z", " ")) end
  end
  local h = io.popen(string.format("ps -p %d -o args= 2>/dev/null", pid))
  if h then
    local s = (h:read("*a") or ""):gsub("%s+$", "")
    h:close()
    if s ~= "" then return s end
  end
  return nil
end

-- Injetável nos testes: troca os comandos do sistema por simulações.
M.exec = {
  popen   = function(cmd) return io.popen(cmd) end,
  execute = function(cmd) return os.execute(cmd) end,
  cmdline = read_cmdline,
}

-- O sistema operacional impõe o prazo do filho (mesmo que o pai morra): usa `timeout` se existir.
local function has_timeout()
  if M._has_timeout == nil then
    M._has_timeout = M.exec.execute("command -v timeout >/dev/null 2>&1") == true
  end
  return M._has_timeout
end

-- O pid ainda é o worker deste run? Evita tratar (ou matar) um pid reaproveitado por outro
-- programa. Se a identidade não puder ser lida, assume que é o mesmo (comportamento anterior).
local function is_worker(pid, run_id)
  if not run_id then return true end
  local cmd = M.exec.cmdline(pid)
  if not cmd then return true end
  return cmd:find("--worker " .. run_id, 1, true) ~= nil
end

-- Inicia "TermAI run --worker <run_id>" em segundo plano e devolve o pid.
-- timeout_s: prazo em segundos (+30 s de folga) aplicado pelo sistema operacional.
function M.start(run_id, timeout_s)
  local interp = (arg and arg[-1]) or "lua5.4"
  local script = (os.getenv("HOME") or "") .. "/TermAI/main.lua"
  local errlog = registry.dir(run_id) .. "/stderr.log"
  local outlog = registry.dir(run_id) .. "/stdout.log"
  local prefix = ""
  if timeout_s and timeout_s > 0 and has_timeout() then
    prefix = string.format("timeout -k 10 %d ", math.floor(timeout_s) + 30)
  end
  local cmd = string.format("%s'%s' '%s' run --worker '%s' >>'%s' 2>>'%s' & echo $!",
    prefix, interp, script, run_id, outlog, errlog)
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

function M.alive(pid, run_id)
  if not pid then return false end
  if M.exec.execute(string.format("kill -0 %d 2>/dev/null", pid)) ~= true then return false end
  return is_worker(pid, run_id)
end

function M.kill(pid, run_id)
  if not pid then return end
  if not is_worker(pid, run_id) then
    log.warn("launcher_kill_skipped", { child_pid = pid, run_id = run_id, reason = "pid de outro programa" })
    return
  end
  M.exec.execute(string.format("kill -TERM %d 2>/dev/null", pid))
  log.info("launcher_kill", { child_pid = pid })
end

return M
