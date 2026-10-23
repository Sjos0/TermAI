-- tests/issues_77_66_spec.lua — #77 (--ag vazio) e #66 (lista de tools no erro).
package.path = "./?.lua;./?/init.lua;" .. package.path

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

-- #77: --ag precisa de um nome de agente.
local parser = require("tools.skills.skills_installer.parser")
local p1 = parser.parse({ "install", "https://example.invalid/x", "--ag", "", "--skill", "foo" })
check(p1.error ~= nil and p1.flags.agent == nil, "#77: --ag vazio vira erro, sem agent = ''")
local p2 = parser.parse({ "install", "https://example.invalid/x", "--skill", "foo", "--ag" })
check(p2.error ~= nil and p2.flags.agent == nil, "#77: --ag no fim (sem valor) vira erro")
local p3 = parser.parse({ "install", "https://example.invalid/x", "--ag", "--skill", "foo" })
check(p3.error ~= nil and p3.flags.agent == nil, "#77: --ag seguido de outra flag vira erro")
local p4 = parser.parse({ "install", "https://example.invalid/x", "--ag", "main", "--skill", "foo" })
check(p4.error == nil and p4.flags.agent == "main", "#77: --ag com nome válido continua funcionando")

-- #66: a lista de tools no erro vem do registro real e inclui as que faltavam.
require("tools")
local feedback = require("tools.error_feedback.feedback")
local out = feedback.generate({ { type = "unknown_tool", tool_name = "ZzzInexistente" } })
for _, name in ipairs({ "Grep", "web_fetch", "todo_write", "Exec", "Read" }) do
  check(out:find(name, 1, true) ~= nil, "#66: lista de tools inclui " .. name)
end
check(out:find("ZzzInexistente", 1, true) ~= nil, "#66: mensagem ainda cita a tool errada")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
