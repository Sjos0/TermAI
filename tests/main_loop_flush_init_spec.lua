-- tests/main_loop_flush_init_spec.lua — init de flush_msgs_start (Issue #363).
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local saved
package.loaded["session"] = {
  get_flush_index = function() return saved end,
}
package.loaded["agent.main_loop.flush_init"] = nil
local flush_init = require("agent.main_loop.flush_init")

saved = 10
T(flush_init.compute({ msgs = {1,2,3,4,5,6,7,8,9,10,11,12} }) == 11,
  "sessão com índice salvo: saved+1")

saved = nil
local legacy = {}
for i = 1, 20 do legacy[i] = i end
T(flush_init.compute({ msgs = legacy }) == 5,
  "legado: max(1, #msgs-15) com 20 msgs → 5")

local short = {1, 2, 3}
T(flush_init.compute({ msgs = short }) == 1,
  "legado curto: max(1, 3-15) → 1")

T(flush_init.compute({ msgs = {} }) == 1,
  "sessão vazia: #msgs+1 → 1")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
