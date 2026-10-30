-- tests/tui_spinner_cleanup_startup_spec.lua — cleanup_startup (#222: slot por dono).
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
  if not (ok and code == 0) then return false end
  local f = io.open("/proc/" .. pid .. "/stat", "r")
  if not f then return true end
  local stat = f:read("*l") or ""; f:close()
  return stat:match("%)%s+(%a)") ~= "Z"
end

-- 1. Flags e payloads legados (sem pid no nome) são removidos.
write_file(dir .. "/ta_inject.flag", "1")
write_file(dir .. "/termai_stream.flag", "1")
write_file(dir .. "/ta_payload_123_1", "{}") -- owner 123 morto
write_file(dir .. "/ta_spin.sh", "#!/bin/sh\n")

launch.cleanup_startup()
check(not exists(dir .. "/ta_inject.flag"), "cleanup_startup remove ta_inject.flag")
check(not exists(dir .. "/termai_stream.flag"), "cleanup_startup remove termai_stream.flag")
check(not exists(dir .. "/ta_payload_123_1"), "cleanup_startup remove payload de dono morto")

-- 2. Spinner de dono morto (ta_pid_<dead>): cleanup mata.
local dead = "999990"
local sh_path = dir .. "/ta_spin_" .. dead .. ".sh"
write_file(sh_path, "#!/bin/sh\ntrap 'exit 0' TERM\nwhile true; do sleep 1; done\n")
os.execute("chmod +x " .. sh_path)
os.execute("sh " .. sh_path .. " & echo $! > " .. dir .. "/ta_pid_" .. dead)
local pid_f = io.open(dir .. "/ta_pid_" .. dead, "r")
local pid = pid_f and pid_f:read("*l") or ""
if pid_f then pid_f:close() end
check(alive(pid), "spinner orfao simulado vivo (" .. tostring(pid) .. ")")
launch.cleanup_startup()
check(not alive(pid), "cleanup mata spinner de dono morto (" .. tostring(pid) .. ")")
check(not exists(dir .. "/ta_pid_" .. dead), "remove ta_pid de dono morto")

-- 3. Não-spinner: legado ta_pid apontando para sleep — não mata o processo.
os.execute("sleep 30 & echo $! > " .. dir .. "/ta_pid")
local pid2_f = io.open(dir .. "/ta_pid", "r")
local pid2 = pid2_f and pid2_f:read("*l") or ""
if pid2_f then pid2_f:close() end
launch.cleanup_startup()
check(alive(pid2), "NAO mata pid que nao e o spinner (" .. tostring(pid2) .. ")")
os.execute("kill -KILL " .. tostring(pid2) .. " 2>/dev/null")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
