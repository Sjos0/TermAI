-- tests/loop_turno_erro_spec.lua — M.rodar protege com pcall: erro em rodar_turno
-- não derruba a TUI, turn_end e kill_spinner sempre rodam, e o erro sai em c.red.
-- Também garante que o caminho de SUCESSO continua intacto (r é a tabela pack).
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local events = {}
local pensar_stream_impl = nil

package.loaded["ui"] = {
  start_thinking = function() end,
  is_running = function() return false end,
  stop_thinking = function() return 0 end,
  kill_spinner = function() events[#events + 1] = "kill_spinner" end,
  agent_limit = function() end,
  show_api_error = function(msg)
    io.write("\27[38;5;203m" .. tostring(msg) .. "\27[0m\n")
  end,
}
package.loaded["ui.spinner.rotulo"] = {
  regiao_ativa = function() return false end,
  evento = function(e) events[#events + 1] = "evento:" .. e end,
}
package.loaded["ui.core"] = {
  c = { red = "\27[38;5;203m", reset = "\27[0m" },
}
package.loaded["agent.api"] = {
  pensar_stream = function(...) return pensar_stream_impl(...) end,
}
package.loaded["agent.loop.system_messages"] = {
  prepare_user_turn = function(ctx, t, role) return t, false end,
}
package.loaded["agent.loop.json_path"] = {
  handle = function() return {} end,
}
package.loaded["agent.loop.xml_path"] = {
  handle = function()
    return { action = "return", resp = "PONG", elapsed = 0, flush_done = false,
             is_overflow = false, stream_complete = true, last_reasoning = "" }
  end,
}
package.loaded["tools.subagents"] = {
  bind = function() end,
  on_boundary = function() end,
}

local loop = require("agent.loop")
local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

-- ══════════════ CASO 1: ERRO INJETADO ══════════════
events = {}
pensar_stream_impl = function() error("erro injetado no stream") end

local ctx1 = { is_subagent = false, MAX_ITER = 3, msgs = {}, cfg = {} }
local written = {}
local real_write = io.write
io.write = function(...) for _, v in ipairs({...}) do written[#written + 1] = tostring(v) end end
local resp1, elapsed1, fd1, ov1, sc1, rz1 = loop.rodar(ctx1, "teste", "user")
io.write = real_write

check(resp1 == "", "erro: retorna resp vazio")
check(ov1 == false, "erro: is_overflow false")
check(sc1 == false, "erro: stream_complete false (#205)")
check(table.concat(written):find("\27[38;5;203m", 1, true) ~= nil, "erro: exibido em c.red")
check(table.concat(written):find("erro injetado", 1, true) ~= nil, "erro: mensagem aparece no output")

local turn_end1, kill1 = false, false
for _, e in ipairs(events) do
  if e == "evento:turn_end" then turn_end1 = true end
  if e == "kill_spinner" then kill1 = true end
end
check(turn_end1, "erro: turn_end rodou mesmo com erro")
check(kill1, "erro: kill_spinner rodou mesmo com erro")

-- ══════════════ CASO 2: SUCESSO ══════════════
events = {}
pensar_stream_impl = function() return "PONG", false, true, "", nil end

local ctx2 = { is_subagent = false, MAX_ITER = 3, msgs = {}, cfg = {} }
local resp2, elapsed2, fd2, ov2, sc2, rz2 = loop.rodar(ctx2, "ok", "user")

check(resp2 == "PONG", "sucesso: resposta final volta intacta (PONG)")
check(ov2 == false, "sucesso: is_overflow false")
check(sc2 == true, "sucesso: stream_complete true")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
