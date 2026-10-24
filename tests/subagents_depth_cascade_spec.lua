package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- tests/subagents_depth_cascade_spec.lua — paridade OpenClaw lote 1: profundidade (maxSpawnDepth),
-- roteamento do anúncio por run pai, e cascata (matar e órfãos). Padrão preserva o comportamento atual.
package.path = "./?.lua;./?/init.lua;" .. package.path
local portable_tmp = require("tests.helpers.tmp")

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local root = portable_tmp.name("termai_depth_test")
os.execute("mkdir -p '" .. root .. "'")
require("config.store").PATH = root .. "/config.json"
require("config.store")._data = nil
require("tools.agents.paths").base_override = root

local registry  = require("tools.subagents.registry")
local scheduler = require("tools.subagents.scheduler")
local spawn     = require("tools.subagents.spawn")
local announce  = require("tools.subagents.announce")
local control   = require("tools.subagents.control")
local launcher  = require("tools.subagents.launcher")

-- Nada de processo real: kill é só registrado.
local killed = {}
launcher.exec.execute = function(cmd)
  local p = cmd:match("kill %-TERM (%d+)")
  if p then killed[#killed + 1] = p end
  return true
end
launcher.exec.cmdline = function() return nil end

local function run(id, o)
  registry.save({ runId = id, kind = "clone", agentId = "main", task = "t", status = o.status or "running",
    created_at = os.time() - 10, started_at = os.time() - 9,
    finished_at = (o.status and o.status ~= "running" and o.status ~= "queued") and os.time() or nil,
    parent_agent = o.parent_agent or "main", parent_run = o.parent_run, depth = o.depth or 1,
    cleanup = "retain", announce_consumed = o.consumed or false, pid = o.pid })
  if o.result then registry.write_result(id, o.result) end
end
local function status(id) return registry.load(id).status end

-- (1) Regra de profundidade pura: padrão 1 = subagente não cria filho.
check(spawn.can_nest(0, 1) == true, "padrão: agente principal (0) pode criar filho (profundidade 1)")
check(spawn.can_nest(1, 1) == false, "padrão: subagente (1) NÃO cria filho (preserva o comportamento atual)")
check(spawn.can_nest(1, 2) == true, "maxSpawnDepth=2: subagente de nível 1 cria filho de nível 2")
check(spawn.can_nest(2, 2) == false, "maxSpawnDepth=2: nível 2 não cria nível 3")
check(scheduler.limits({}).maxSpawnDepth == 1, "limite padrão de maxSpawnDepth é 1")
local cfg2 = { agents = { defaults = { subagents = { maxSpawnDepth = 3 } } } }
check(scheduler.limits(cfg2).maxSpawnDepth == 3, "maxSpawnDepth vem da config")

-- (2) Anúncio por run pai: filho de um subagente não é entregue ao agente principal.
run("sub-a1", { status = "completed", parent_run = "sub-f0", depth = 2, consumed = false })
local ctx_main = { agent_id = "main", msgs = {} }
local _, n_main = (function() local o = io.write; local b = {}; io.write = function(...) for _, v in ipairs({...}) do b[#b+1] = tostring(v) end end; local n = announce.inject(ctx_main); io.write = o; return table.concat(b), n end)()
check(n_main == 0, "anúncio: o agente principal não recebe o resultado de um filho aninhado")
local buf = {}
local orig = io.write; io.write = function(...) for _, v in ipairs({...}) do buf[#buf+1] = tostring(v) end end
local ctx_sub = { agent_id = "main", run_id = "sub-f0", msgs = {} }
local n_sub = announce.inject(ctx_sub)
io.write = orig
check(n_sub == 1, "anúncio: o run pai (sub-f0) recebe o resultado do próprio filho")

-- (3) Cascata por matar: a árvore inteira (filhos e netos) é encerrada.
killed = {}
run("sub-b1", { status = "running", pid = 9101 })
run("sub-b2", { status = "running", parent_run = "sub-b1", depth = 2, pid = 9102 })
run("sub-b3", { status = "running", parent_run = "sub-b2", depth = 3, pid = 9103 })
run("sub-b4", { status = "completed", parent_run = "sub-b1", depth = 2 })   -- já terminado: não conta
local r = control.matar({ runId = "sub-b1" })
check(status("sub-b1") == "killed", "matar: o próprio run fica killed")
check(status("sub-b2") == "killed" and status("sub-b3") == "killed", "matar: filhos e netos ativos ficam killed")
check(status("sub-b4") == "completed", "matar: filho já terminado não é tocado")
check(#killed >= 2, "matar: processos dos filhos recebem kill (" .. #killed .. ")")

-- (4) Órfãos: pai terminou (falhou) e o filho ainda roda -> cascata encerra.
run("sub-d1", { status = "failed", depth = 1 })
run("sub-d2", { status = "running", parent_run = "sub-d1", depth = 2, pid = 9201 })
scheduler.tick({})
check(status("sub-d2") == "killed", "órfão: filho ativo de pai terminado é encerrado no tick")
check(registry.load("sub-d2").error == "pai encerrou", "órfão: motivo registrado")

-- (5) Ciclo não trava a árvore (proteção contra registro corrompido).
run("sub-e1", { status = "running", parent_run = "sub-e2", depth = 2, pid = 9301 })
run("sub-e2", { status = "running", parent_run = "sub-e1", depth = 2, pid = 9302 })
local stopped = scheduler.stop_tree("sub-e1", "teste de ciclo")
check(stopped == 1 and status("sub-e2") == "killed", "ciclo na árvore não trava e encerra o outro ramo")

os.execute("rm -rf '" .. root .. "'")
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
