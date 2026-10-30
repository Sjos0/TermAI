-- tests/cleanup_startup_pid_spec.lua — #204: cleanup não toca PID vivo
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local tmp = "/tmp/ta_clean_test_" .. tostring(os.time())
os.execute("mkdir -p " .. tmp)

-- simula PID vivo: usa o próprio processo
local f = io.open("/proc/self/stat", "r")
local my = (f:read("*l") or ""):match("^(%d+)"); f:close()
local payload = tmp .. "/ta_payload_" .. my .. "_1"
local pidfile = tmp .. "/ta_pid_" .. my
io.open(payload, "w"):write("x"):close()
io.open(pidfile, "w"):write(my):close()

local dead = "999999"
io.open(tmp .. "/ta_payload_" .. dead .. "_1", "w"):write("y"):close()
io.open(tmp .. "/ta_pid_" .. dead, "w"):write(dead):close()

require("ui.spinner.cleanup_startup").run(tmp)

local live_ok = io.open(payload, "r") ~= nil
local dead_gone = io.open(tmp .. "/ta_payload_" .. dead .. "_1", "r") == nil
T(live_ok, "payload de PID vivo preservado")
T(dead_gone, "payload de PID morto removido")

os.execute("rm -rf " .. tmp)
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
