-- tests/cleanup_startup_pid_spec.lua — #204
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local tmp = "/tmp/ta_clean_test_" .. tostring(os.time())
os.execute("mkdir -p " .. tmp)
local f = io.open("/proc/self/stat", "r")
local my = (f:read("*l") or ""):match("^(%d+)"); f:close()
local payload = tmp .. "/ta_payload_" .. my .. "_1"
io.open(payload, "w"):write("x"):close()
local dead = "999999"
io.open(tmp .. "/ta_payload_" .. dead .. "_1", "w"):write("y"):close()
require("ui.spinner.cleanup_startup").run(tmp, {})
T(io.open(payload, "r") ~= nil, "payload PID vivo preservado")
T(io.open(tmp .. "/ta_payload_" .. dead .. "_1", "r") == nil, "payload PID morto removido")
os.execute("rm -rf " .. tmp)
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
