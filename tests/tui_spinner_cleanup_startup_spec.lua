-- tests/tui_spinner_cleanup_startup_spec.lua — cleanup_startup: limpa resíduos
-- de execuções anteriores (spinner órfão + flags/payloads) no início do TUI.
-- Garante: flags/payloads residuais são removidos; o spinner órfão é morto só
-- quando o processo ainda é o spinner (validação via /proc/<pid>/cmdline).
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
do
  local real_getenv = os.getenv
  local tmp = real_getenv("TMPDIR") or "/tmp"
  os.getenv = function(k) if k == "TMPDIR" then return tmp end return real_getenv(k) end
end
local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local dir = os.getenv("TMPDIR") or "/tmp"
local launch = require("ui.spinner.launch")

local function write_file(p, s) local f = io.open(p, "w"); f:write(s); f:close() end
local function exists(p) return io.open(p, "r") ~= nil end
local function alive(pid)
  local ok, _, code = os.execute("kill -0 " .. pid .. " 2>/dev/null")
  return ok and code == 0
end

-- 1. Flags e payloads residuais são removidos.
write_file(dir .. "/ta_inject.flag", "1")
write_file(dir .. "/termai_stream.flag", "1")
write_file(dir .. "/ta_payload_123_1", "{}")
write_file(dir .. "/ta_spin.sh", "#!/bin/sh\ntrap 'exit 0' TERM\nwhile true; do sleep 1; done\n")

launch.cleanup_startup()
check(not exists(dir .. "/ta_inject.flag"), "cleanup_startup remove ta_inject.flag")
check(not exists(dir .. "/termai_stream.flag"), "cleanup_startup remove termai_stream.flag")
check(not exists(dir .. "/ta_payload_123_1"), "cleanup_startup remove ta_payload_*")

-- 2. Spinner órfão real: sobe um processo ta_spin.sh, registra o pid, cleanup mata.
local sh_path = dir .. "/ta_spin.sh"
write_file(sh_path, "#!/bin/sh\ntrap 'exit 0' TERM\nwhile true; do sleep 1; done\n")
os.execute("chmod +x " .. sh_path)
os.execute("sh " .. sh_path .. " & echo $! > " .. dir .. "/ta_pid")
local pid_f = io.open(dir .. "/ta_pid", "r")
local pid = pid_f and pid_f:read("*l") or ""
if pid_f then pid_f:close() end
check(alive(pid), "spinner órfão simulado tem pid válido (" .. pid .. ")")
launch.cleanup_startup()
local alive_spinner = alive(pid)
check(not alive_spinner, "cleanup_startup mata o spinner órfão (pid " .. pid .. ")")
check(not exists(dir .. "/ta_pid"), "cleanup_startup remove ta_pid")

-- 3. Validação: um pid que NÃO é o spinner não deve ser morto.
os.execute("sleep 30 & echo $! > " .. dir .. "/ta_pid")
local pid2_f = io.open(dir .. "/ta_pid", "r")
local pid2 = pid2_f and pid2_f:read("*l") or ""
if pid2_f then pid2_f:close() end
launch.cleanup_startup()
local alive2 = alive(pid2)
check(alive2, "cleanup_startup NAO mata pid que nao e o spinner (pid " .. pid2 .. ")")
os.execute("kill -KILL " .. pid2 .. " 2>/dev/null")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
