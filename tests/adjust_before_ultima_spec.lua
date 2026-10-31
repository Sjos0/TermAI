-- tests/adjust_before_ultima_spec.lua — #279: adjust_before pega última ocorrência.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
package.loaded["session"] = { save_message = function() end, save_session_tokens = function() end }
package.loaded["agent.main_loop.persistence"] = nil
local persistence = require("agent.main_loop.persistence")
local stamped = "[12:00] mesma"
local ctx = {
  msgs = {
    { role = "user", content = stamped },
    { role = "assistant", content = "ok" },
    { role = "user", content = stamped }, -- última
  },
}
-- msgs_before aponta para situação deslocada
local before = persistence.adjust_before(ctx, 10, stamped)
T(before == 2, "adjust_before devolve índice da ÚLTIMA ocorrência-1 (got " .. tostring(before) .. " want 2)")
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
