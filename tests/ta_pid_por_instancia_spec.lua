-- tests/ta_pid_por_instancia_spec.lua — #222: startup B não mata spinner de A vivo
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local tmp = "/tmp/ta_pid_test_" .. tostring(os.time())
os.execute("mkdir -p " .. tmp)

local function alive(pid)
  local f = io.open("/proc/" .. pid .. "/stat", "r")
  if not f then return false end
  local s = f:read("*l") or ""; f:close()
  return (s:match("^%d+ %S+ (%S)") or "Z") ~= "Z"
end

-- Instância A: script ta_spin e ta_pid_A
local sh = tmp .. "/ta_spin_A.sh"
local f = io.open(sh, "w")
f:write("#!/bin/sh\ntrap 'exit 0' TERM\nwhile true; do sleep 1; done\n"); f:close()
os.execute("chmod +x " .. sh)
os.execute("sh " .. sh .. " & echo $! > " .. tmp .. "/ta_pid_A")
local pf = io.open(tmp .. "/ta_pid_A", "r")
local spin_a = pf and pf:read("*l") or ""; if pf then pf:close() end
-- renomeia para formato real ta_pid_<owner>
-- owner fictício vivo = self
local self_f = io.open("/proc/self/stat", "r")
local self_pid = (self_f:read("*l") or ""):match("^(%d+)"); self_f:close()
os.execute("mv " .. tmp .. "/ta_pid_A " .. tmp .. "/ta_pid_" .. self_pid)
os.execute("mv " .. sh .. " " .. tmp .. "/ta_spin_" .. self_pid .. ".sh")
-- rewrite pid file content = spin_a
local out = io.open(tmp .. "/ta_pid_" .. self_pid, "w"); out:write(spin_a); out:close()

T(alive(spin_a), "spinner A vivo antes do cleanup B")

local cleanup = require("ui.spinner.cleanup_startup")
cleanup.run(tmp, {
  is_spinner = function(pid)
    local cf = io.open("/proc/" .. pid .. "/cmdline", "r")
    if not cf then return false end
    local c = cf:read("*a") or ""; cf:close()
    return c:find("ta_spin", 1, true) ~= nil
  end,
})

T(alive(spin_a), "spinner A continua vivo apos cleanup B (dono self vivo)")
T(io.open(tmp .. "/ta_pid_" .. self_pid, "r") ~= nil, "ta_pid do dono vivo preservado")

-- Instância morta: owner 999991
local dead_owner = "999991"
local sh2 = tmp .. "/ta_spin_" .. dead_owner .. ".sh"
local g = io.open(sh2, "w")
g:write("#!/bin/sh\ntrap 'exit 0' TERM\nwhile true; do sleep 1; done\n"); g:close()
os.execute("chmod +x " .. sh2)
os.execute("sh " .. sh2 .. " & echo $! > " .. tmp .. "/ta_pid_" .. dead_owner)
local pf2 = io.open(tmp .. "/ta_pid_" .. dead_owner, "r")
local spin_dead = pf2 and pf2:read("*l") or ""; if pf2 then pf2:close() end
T(alive(spin_dead), "spinner orfao vivo antes")

cleanup.run(tmp, {
  is_spinner = function(pid)
    local cf = io.open("/proc/" .. pid .. "/cmdline", "r")
    if not cf then return false end
    local c = cf:read("*a") or ""; cf:close()
    return c:find("ta_spin", 1, true) ~= nil
  end,
})

T(not alive(spin_dead), "spinner de dono morto foi morto")
T(io.open(tmp .. "/ta_pid_" .. dead_owner, "r") == nil, "ta_pid de dono morto removido")

-- Não-spinner nunca morto
local ns = io.popen("sleep 30 & echo $!")
local nspid = (ns:read("*l") or ""):match("%d+"); ns:close()
local bad = tmp .. "/ta_pid_888888"
local bf = io.open(bad, "w"); bf:write(nspid); bf:close()
cleanup.run(tmp, {
  is_spinner = function() return false end,
})
T(alive(nspid), "processo nao-spinner nao e morto")
os.execute("kill -KILL " .. tostring(nspid) .. " 2>/dev/null")
os.execute("kill -KILL " .. tostring(spin_a) .. " 2>/dev/null")
os.execute("rm -rf " .. tmp)

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
