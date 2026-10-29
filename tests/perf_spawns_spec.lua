-- tests/perf_spawns_spec.lua — cache de get_ms_time: dentro do mesmo segundo,
-- não spawna `date` a cada chamada (#185).
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local date_spawns = 0
local real_popen = io.popen
io.popen = function(cmd)
  if type(cmd) == "string" and cmd:find("date +%s%3N", 1, true) then
    date_spawns = date_spawns + 1
    return { read = function() return "1000000000123" end, close = function() end }
  end
  return real_popen(cmd)
end

local timing = require("ui.spinner.timing")

-- chama get_ms_time várias vezes no mesmo segundo
local v1 = timing.get_ms_time()
local v2 = timing.get_ms_time()
local v3 = timing.get_ms_time()

io.popen = real_popen

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

check(date_spawns <= 1, "get_ms_time só spawna date 1x por segundo (spawns=" .. date_spawns .. ")")
check(v1 == v2 and v2 == v3, "valores consistentes dentro do mesmo segundo")
check(v1 == 1000000000123, "valor lido do date é retornado corretamente")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
