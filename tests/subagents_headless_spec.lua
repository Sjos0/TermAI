package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- tests/subagents_headless_spec.lua — --wait-subagents na execução headless (#92).
package.path = "./?.lua;./?/init.lua;" .. package.path
local portable_tmp = require("tests.helpers.tmp")

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local root = portable_tmp.name("termai_hl_test")
os.execute("mkdir -p '" .. root .. "'")
require("tools.agents.paths").base_override = root

local registry = require("tools.subagents.registry")
local hw       = require("tools.subagents.headless_wait")

-- Tick, sleep e relógio injetados: nada de processo real.
local clock, sleeps = 1000, 0
hw.tick  = function() end
hw.now   = function() return clock end
hw.sleep = function() sleeps = sleeps + 1; clock = clock + 1 end

local function run(id, status, parent, consumed)
  registry.save({ runId = id, kind = "clone", agentId = "main", task = "t", status = status,
    created_at = clock - 5, started_at = clock - 4, finished_at = (status ~= "running") and clock or nil,
    parent_agent = parent or "main", cleanup = "retain", announce_consumed = consumed or false })
  registry.write_result(id, "R-" .. id)
end

-- (1) Sem filhos: sai na hora.
local st0, p0 = hw.run({}, "main", 60)
check(st0 == "ok" and #p0 == 0, "sem filhos: retorna ok na hora")

-- (2) Filho ativo, prazo zero: timeout e a lista traz o pendente.
run("sub-d1", "running")
local st1, p1 = hw.run({}, "main", 0)
check(st1 == "timeout" and #p1 == 1 and p1[1].runId == "sub-d1", "filho ativo com prazo zero: timeout com o pendente")-- sub-d1 termina aqui, para não bloquear os passos seguintes (a espera olha todos os ativos do pai).
do local r = registry.load("sub-d1"); r.status, r.finished_at = "completed", clock; registry.save(r) end

-- (3) Espera de verdade: o filho termina depois de 3 segundos.
run("sub-d2", "running")
sleeps = 0
local realsleep = hw.sleep
hw.sleep = function()
  realsleep()
  if sleeps == 3 then
    local r = registry.load("sub-d2"); r.status, r.finished_at = "completed", clock
    registry.save(r)
  end
end
local st2 = hw.run({}, "main", 60)
check(st2 == "ok", "espera: retorna ok quando o filho termina")
check(sleeps == 3, "espera: dorme só enquanto há filho ativo (dormiu " .. sleeps .. "x)")
hw.sleep = realsleep

-- (4) Isolamento por pai: filho de outro pai não bloqueia a espera do main.
run("sub-d3", "running", "outro")
local st4 = hw.run({}, "main", 0)
check(st4 == "ok", "filho de outro pai não bloqueia o main")

-- (5) print_results: entrega cada filho terminado uma vez, e não repete.
local texts = hw.print_results("main")
local joined = table.concat(texts, "\n")
check(#texts >= 1 and joined:find("R-sub-d2", 1, true) ~= nil, "print_results: traz o resultado do filho concluído")
check(#hw.print_results("main") == 0, "print_results: não repete o que já foi entregue")

-- (6) Teto de 900 s: pedido acima é limitado.
check(hw.MAX_SECONDS == 900, "teto de 900 s para --wait-subagents")

os.execute("rm -rf '" .. root .. "'")
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
