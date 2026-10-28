-- tests/tui_fase_spec.lua — Issue #176 P3: rótulos do spinner seguem o turno (sem voltar a Requisitando).
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local fase = require("ui.spinner.fase")
local s = fase.new()
check(s == "idle" and fase.label(s) == nil, "começa ocioso, sem rótulo")

s = fase.on(s, "user_send")
check(fase.label(s) == "Injetando", "usuário envia → Injetando")
s = fase.on(s, "inject_done")
check(fase.label(s) == "Requisitando", "injeção pronta → Requisitando")
s = fase.on(s, "agent_turn")
check(fase.label(s) == "Trabalhando", "agente assume o turno → Trabalhando")

s = fase.on(s, "agent_turn")
s = fase.on(s, "user_send")
s = fase.on(s, "inject_done")
check(fase.label(s) == "Trabalhando", "dentro do turno não volta a Requisitando nem Injetando")

s = fase.on(s, "turn_end")
check(s == "idle" and fase.label(s) == nil, "turn_end → ocioso")

s = fase.on("idle", "turn_end")
check(s == "idle", "evento fora de ordem é ignorado")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
