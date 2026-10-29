-- tests/loop_turno_erro_spec.lua — M.rodar protege com pcall: erro em rodar_turno
-- não derruba a TUI, turn_end e kill_spinner sempre rodam, e o erro sai em c.red.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local events = {}

package.loaded["ui"] = {
  start_thinking = function() end,
  is_running = function() return false end,
  stop_thinking = function() return 0 end,
  kill_spinner = function() events[#events + 1] = "kill_spinner" end,
  agent_limit = function() end,
}
package.loaded["ui.spinner.rotulo"] = {
  regiao_ativa = function() return false end,
  evento = function(e) events[#events + 1] = "evento:" .. e end,
}
package.loaded["ui.core"] = {
  c = { red = "\27[38;5;203m", reset = "\27[0m" },
}
package.loaded["agent.api"] = {
  pensar_stream = function() error("erro injetado no stream") end,
}
package.loaded["agent.loop.system_messages"] = {
  prepare_user_turn = function(ctx, t, role) return t, false end,
}
package.loaded["agent.loop.json_path"] = {
  handle = function() return {} end,
}
package.loaded["agent.loop.xml_path"] = {
  handle = function() return { action = "continue" } end,
}
package.loaded["tools.subagents"] = {
  bind = function() end,
  on_boundary = function() end,
}

local loop = require("agent.loop")
local ctx = { is_subagent = false, MAX_ITER = 3, msgs = {}, cfg = {} }

local written = {}
local real_write = io.write
io.write = function(...) for _, v in ipairs({...}) do written[#written + 1] = tostring(v) end end
local resp, elapsed, flush_done, is_overflow, stream_complete, reasoning = loop.rodar(ctx, "teste", "user")
io.write = real_write

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

check(resp == "", "retorna resp vazio em erro")
check(is_overflow == false, "is_overflow false em erro")
check(stream_complete == true, "stream_complete true em erro (sem aviso de corte)")
check(table.concat(written):find("\27[38;5;203m", 1, true) ~= nil, "erro exibido em c.red")
check(table.concat(written):find("erro injetado", 1, true) ~= nil, "mensagem do erro aparece no output")

local has_turn_end = false
local has_kill = false
for _, e in ipairs(events) do
  if e == "evento:turn_end" then has_turn_end = true end
  if e == "kill_spinner" then has_kill = true end
end
check(has_turn_end, "turn_end rodou mesmo com erro")
check(has_kill, "kill_spinner rodou mesmo com erro")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
