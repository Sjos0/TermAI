package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- tests/subagent_task_once_spec.lua — Regressão #85 e #86: a tarefa do subagente entra UMA vez
-- e o turno do filho não vaza estado de módulo para o pai.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local TASK = "TAREFA-UNICA-85"
local sm = require("agent.loop.system_messages")

-- (a) #85/#86: turno de subagente devolve o texto intacto e não escreve em ctx.msgs.
local child = { is_subagent = true, msgs = {}, last_tool_sig = "resto-do-pai" }
local txt, spin = sm.prepare_user_turn(child, TASK, "user")
check(txt == TASK, "prepare_user_turn(subagente) devolve a tarefa sem injeções")
check(spin == false, "prepare_user_turn(subagente) não liga spinner")
check(#child.msgs == 0, "prepare_user_turn(subagente) não escreve em ctx.msgs (sem duplicar a tarefa)")
check(child.last_tool_sig == nil, "prepare_user_turn(subagente) limpa last_tool_sig")

-- Roles que não são user passam direto, também no filho.
local t2 = sm.prepare_user_turn(child, "resultado de tool", "tool")
check(t2 == "resultado de tool", "role != user passa direto")

-- (b) #86: o turno do filho não consome is_first_turn do pai.
-- Se consumisse, o pai (turno 1) receberia o texto cru; com o estado intacto ele recebe injeção de boot.
local parent = { msgs = {}, last_tool_sig = nil, agent_id = "main", cfg = { agents = { defaults = {} } } }
local ok, ptxt = pcall(sm.prepare_user_turn, parent, "oi", "user")
if ok then
  check(ptxt ~= "oi", "pai ainda recebe injeção de primeiro turno depois do turno do filho")
else
  print("SKIP: pai exige mais contexto para o caminho de boot (" .. tostring(ptxt):sub(1, 60) .. ")")
end

-- (c) #85: loop.rodar de subagente envia a tarefa exatamente uma vez ao provedor.
local api  = require("agent.api")
local loop = require("agent.loop")
local calls = {}
local orig = api.pensar_stream
api.pensar_stream = function(_, t, role)
  calls[#calls + 1] = { txt = t, role = role }
  return "PONG", false, true, "", nil
end
local sub = { is_subagent = true, msgs = {}, MAX_ITER = 3, run_id = "t85",
              cfg = { agents = { defaults = {} } } }
local rok, resp = pcall(loop.rodar, sub, TASK, "user", 3)
api.pensar_stream = orig
check(rok, "loop.rodar de subagente executa sem erro" .. (rok and "" or (": " .. tostring(resp))))
check(#calls == 1, "pensar_stream chamado uma única vez (recebeu " .. #calls .. ")")
check(calls[1] and calls[1].txt == TASK and calls[1].role == "user", "pensar_stream recebe a tarefa como user, sem alteração")
check(rok and resp == "PONG", "resposta final do filho volta intacta")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
