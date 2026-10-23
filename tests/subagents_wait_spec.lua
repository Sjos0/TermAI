-- tests/subagents_wait_spec.lua — subagents_wait (#95) e progresso no subagents_info.
package.path = "./?.lua;./?/init.lua;" .. package.path

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local root = "/tmp/termai_wait_test_" .. tostring(os.time()) .. "_" .. tostring(math.random(100000))
os.execute("mkdir -p '" .. root .. "'")
require("config.store").PATH = root .. "/config.json"
require("config.store")._data = nil
require("tools.agents.paths").base_override = root

local registry = require("tools.subagents.registry")
local control  = require("tools.subagents.control")

-- Tick e sleep injetados: o teste nunca lança processo real.
local ticks, sleeps = 0, 0
control.tick  = function() ticks = ticks + 1 end
control.sleep = function() sleeps = sleeps + 1 end

local function run(id, o)
  registry.save({ runId = id, kind = "clone", agentId = "main", task = o.task or "tarefa",
    status = o.status, created_at = os.time() - 50, started_at = os.time() - 40,
    finished_at = o.status ~= "running" and os.time() - 10 or nil,
    parent_agent = "main", cleanup = "retain", announce_consumed = false,
    error = o.error })
  if o.result then registry.write_result(id, o.result) end
  if o.event then
    local f = io.open(registry.dir(id) .. "/events.jsonl", "w")
    f:write('{"t":1,"kind":"tool","text":"Read | a.md"}\n{"t":2,"kind":"tool","text":"Grep | x"}\n')
    f:close()
  end
end

-- (1) Run inexistente.
check(control.esperar({ runId = "sub-f0" }):find("não encontrado", 1, true) ~= nil,
  "esperar: run inexistente devolve erro claro")

-- (2) Run já concluído: devolve o resultado na hora e marca como entregue.
run("sub-c1", { status = "completed", result = "RESULTADO-ALFA" })
local out = control.esperar({ runId = "sub-c1", timeoutSeconds = 5 })
check(out:find("RESULTADO-ALFA", 1, true) ~= nil and out:find("status=completed", 1, true) ~= nil,
  "esperar: run concluído devolve o resultado e o status")
check(registry.load("sub-c1").announce_consumed == true, "esperar: marca o run como entregue")
check(sleeps == 0, "esperar: run já concluído não dorme")

-- (3) Run ainda rodando, prazo zero: volta com progresso, sem travar.
run("sub-c2", { status = "running", event = true })
local pend = control.esperar({ runId = "sub-c2", timeoutSeconds = 0 })
check(pend:find("ainda rodando", 1, true) ~= nil, "esperar: prazo estourado devolve aviso de 'ainda rodando'")
check(pend:find("tools=2", 1, true) ~= nil, "esperar: aviso traz o número de tools usadas")
check(registry.load("sub-c2").status == "running", "esperar: não altera um run que ainda está rodando")

-- (4) Espera de verdade: o run termina depois de 2 segundos de espera.
run("sub-c3", { status = "running" })
sleeps = 0
control.sleep = function()
  sleeps = sleeps + 1
  if sleeps == 2 then
    local r = registry.load("sub-c3"); r.status, r.finished_at = "completed", os.time()
    registry.save(r); registry.write_result("sub-c3", "CHEGOU")
  end
end
local got = control.esperar({ runId = "sub-c3", timeoutSeconds = 30 })
check(got:find("CHEGOU", 1, true) ~= nil, "esperar: devolve o resultado quando o run termina no meio da espera")
check(sleeps == 2, "esperar: dorme só enquanto o run está ativo (dormiu " .. sleeps .. "x)")

-- (5) Teto: pedido acima de 300 s é limitado a 300.
check(control.MAX_WAIT == 300, "esperar: teto de 300 s")

-- (6) subagents_info: run em execução traz progresso; run concluído não.
local info = control.info({ runId = "sub-c2" })
check(info:find("Progresso:", 1, true) ~= nil and info:find("tools=2", 1, true) ~= nil,
  "info: run em execução mostra progresso (tools usadas)")
check(control.info({ runId = "sub-c1" }):find("Progresso:", 1, true) == nil,
  "info: run concluído não mostra progresso")

os.execute("rm -rf '" .. root .. "'")
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
