-- tests/recover_persistencia_reinicio_spec.lua — #279: user falho gravado após recover.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local saved = {}
package.loaded["session"] = {
  save_message = function(role, content, tok, skip)
    saved[#saved + 1] = { role = role, content = content, skip = skip }
  end,
  save_session_tokens = function() end,
}
package.loaded["agent.main_loop.persistence"] = nil
local persistence = require("agent.main_loop.persistence")
local recovery = require("agent.api.request_stream.recovery")

local stamped = "[12:00] MENSAGEM QUE FALHOU"
local ctx = {
  msgs = {
    { role = "user", content = "[11:00] anterior" },
    { role = "assistant", tool_calls = { { id = "o1", ["function"] = { name = "web_search" } } } },
    { role = "user", content = stamped },
  },
  tokens = 100,
}
local msgs_before = 2
recovery.recover_tool_seq(ctx.msgs)
T(#ctx.msgs == 2, "apos recover: 2 msgs (got " .. #ctx.msgs .. ")")

-- sem ajuste: bug
saved = {}
persistence.save_exchange(ctx, msgs_before, nil, stamped, true, nil, false)
local bug = false
for _, s in ipairs(saved) do
  if s.role == "user" and tostring(s.content):find("MENSAGEM QUE FALHOU", 1, true) then bug = true end
end
T(not bug and #saved == 0, "sem adjust_before: nada gravado (bug)")

-- com adjust_before (produção)
local before = persistence.adjust_before(ctx, msgs_before, stamped)
T(before == 1, "adjust_before aponta para indice user-1 (got " .. before .. ")")
saved = {}
persistence.save_exchange(ctx, before, nil, stamped, true, nil, false)
local found = false
for _, s in ipairs(saved) do
  if s.role == "user" and tostring(s.content):find("MENSAGEM QUE FALHOU", 1, true) then found = true end
end
T(found, "com adjust_before: MENSAGEM QUE FALHOU gravada")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
