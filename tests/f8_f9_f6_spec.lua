-- tests/f8_f9_f6_spec.lua — F8 (Ctrl+C / saída da TUI com subagentes), F9 (aviso ao reabrir),
-- F6 (progresso na listagem) e plural correto do card.
package.path = "./?.lua;./?/init.lua;" .. package.path

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local root = "/tmp/termai_f8_test_" .. tostring(os.time()) .. "_" .. tostring(math.random(100000))
os.execute("mkdir -p '" .. root .. "'")
require("config.store").PATH = root .. "/config.json"
require("config.store")._data = nil
require("tools.agents.paths").base_override = root

local registry = require("tools.subagents.registry")
local watchdog = require("tools.subagents.watchdog")
local control  = require("tools.subagents.control")
local block    = require("ui.subagent_block")
local card     = require("ui.card")
control.tick = function() end

local function save(id, o)
  registry.save({ runId = id, kind = "clone", agentId = "main", task = "t", status = o.status,
    created_at = os.time() - 30, started_at = os.time() - 20,
    finished_at = (o.status ~= "running" and o.status ~= "queued") and os.time() or nil,
    parent_agent = "main", cleanup = "retain", announce_consumed = o.consumed or false,
    owner_pid = o.owner_pid })
end

-- (1) F8: o dono (TUI) morreu -> o filho se encerra sozinho, com o parcial salvo.
local exited = nil
watchdog.exit = function(code) exited = code end
save("sub-f1", { status = "running", owner_pid = 4242 })
registry.write_partial("sub-f1", "trabalho até aqui")
watchdog.alive = function() return false end
watchdog.check("sub-f1")
local f1 = registry.load("sub-f1")
check(exited == 1, "F8: filho sai quando a TUI que o criou morreu")
check(f1.status == "killed" and f1.error:find("TUI encerrada", 1, true) ~= nil,
  "F8: status killed com o motivo 'TUI encerrada'")
check(f1.partial == true and registry.read_result("sub-f1") == "trabalho até aqui",
  "F8: trabalho parcial é promovido a resultado")

-- (2) Dono vivo: o filho segue (nada muda).
exited = nil
save("sub-f2", { status = "running", owner_pid = 4343 })
watchdog.alive = function() return true end
check(watchdog.check("sub-f2") == false and exited == nil and registry.load("sub-f2").status == "running",
  "F8: dono vivo não encerra o filho")

-- (3) Headless (sem dono): nunca encerra por vigia.
save("sub-f3", { status = "running", owner_pid = nil })
watchdog.alive = function() return false end
exited = nil
check(watchdog.check("sub-f3") == false and exited == nil, "headless sem dono não é vigiado")

-- (4) F9: ao abrir a TUI, um aviso diz quantos terminaram enquanto ela estava fechada (uma vez só).
save("sub-f4", { status = "completed", consumed = false })
save("sub-f5", { status = "failed", consumed = false })
local first = block.pending_lines("main")
check(#first == 1 and first[1]:find("enquanto você estava fora", 1, true) ~= nil,
  "F9: aviso de 'enquanto você estava fora' ao abrir")
check(#block.pending_lines("main") == 0, "F9: o aviso de abertura aparece uma vez só")

-- (5) F6: a listagem mostra tempo e tools dos que estão rodando.
save("sub-f6", { status = "running" })
local listing = control.listar({})
check(listing:find("sub-f6", 1, true) ~= nil and listing:find("tools=", 1, true) ~= nil,
  "F6: listagem mostra progresso (tempo e tools) de run em execução")

-- (6) Plural correto no corpo recolhido.
local one = card.body_rows({ "a", "b", "c", "d", "e", "f" }, 80)
check(one[#one].text == "... (1 linha)", "plural: '1 linha' no singular")
local many = card.body_rows({ "a", "b", "c", "d", "e", "f", "g" }, 80)
check(many[#many].text == "... (2 linhas)", "plural: '2 linhas' no plural")

os.execute("rm -rf '" .. root .. "'")
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
