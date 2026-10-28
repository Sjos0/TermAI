-- tests/tui_spinner_lifecycle_spec.lua — ciclo de vida do spinner (hotfix + robustez).
-- Garante: frames sobrevivem a kill no meio do turno; cleanup_turno limpa tudo;
-- kill nunca emite posicao absoluta; um processo nao fica orfao apos cleanup.
package.path = "./? .lua;./?/init.lua;./lib/?.lua;" .. package.path
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
local rot = require("ui.spinner.rotulo")
local frames = dir .. "/termai_frames.txt"

rot.reset()
rot.evento("user_send")
rot.evento("inject_done")
rot.evento("agent_turn")
check(io.open(frames, "r") ~= nil, "frames de Trabalhando existem apos agent_turn")

local captured = {}
local real_write = io.write
io.write = function(...) for _, v in ipairs({...}) do captured[#captured + 1] = tostring(v) end return io.stdout end
launch.kill_spinner()
io.write = real_write
local emitted = table.concat(captured)
check(io.open(frames, "r") ~= nil, "kill_spinner preserva frames no meio do turno")
check(emitted:find("\27%[%d+;%d+H") == nil, "kill_spinner nao emite posicao absoluta")
check(emitted:find("\r", 1, true) ~= nil, "kill_spinner limpa a linha atual com \\r")

launch.cleanup_turno()
check(io.open(frames, "r") == nil, "cleanup_turno remove frames")
check(io.open(dir .. "/ta_inject.flag", "r") == nil, "cleanup_turno remove inject flag")
check(io.open(dir .. "/ta_pid", "r") == nil, "cleanup_turno remove pidfile")

rot.evento("user_send"); rot.evento("inject_done"); rot.evento("agent_turn")
rot.evento("turn_end")
check(rot.estado() == "idle", "turn_end volta a idle")
check(io.open(frames, "r") == nil, "turn_end remove frames")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
