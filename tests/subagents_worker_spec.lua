package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- tests/subagents_worker_spec.lua — Processo filho: resultado e status gravados (modelo simulado).
package.path = "./?.lua;./?/init.lua;" .. package.path
local portable_tmp = require("tests.helpers.tmp")

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local root = portable_tmp.name("termai_worker_test")
os.execute("mkdir -p '" .. root .. "'")
require("tools.agents.paths").base_override = root

local registry = require("tools.subagents.registry")
local worker   = require("tools.subagents.worker")
local events   = require("tools.subagents.events")

-- Simula agent.context e agent.loop: o "modelo" devolve o que o teste pedir.
local reply, overflow
local last = {}
package.loaded["agent.context"] = { build = function(opts) last.opts = opts; return { MAX_ITER = 3 } end }
package.loaded["agent.loop"] = {
  rodar = function(ctx, input, role, max)
    last.input, last.role, last.max = input, role, max
    return reply, 0, false, overflow, true, ""
  end,
}

local function new_run(task)
  local rec = { runId = registry.new_id(), kind = "agente", agentId = "pesquisa", task = task,
    status = "running", created_at = os.time(), parent_agent = "main", cleanup = "keep" }
  registry.save(rec)
  return rec.runId
end

-- Caso 1: resposta normal.
reply, overflow = "RESUMO FINAL", false
local r1 = new_run("pesquisar Y")
local ok1 = worker.execute(r1)
local rec1 = registry.load(r1)
check(ok1 == true and rec1.status == "completed", "resposta normal marca o run como completed")
check(registry.read_result(r1) == "RESUMO FINAL", "resposta final gravada em result.txt")
check(rec1.error == nil, "completed não grava erro")

-- Caso 2: contexto estourou.
reply, overflow = "", true
local r2 = new_run("tarefa grande")
local ok2, err2 = worker.execute(r2)
check(ok2 == false and registry.load(r2).status == "failed", "estouro de contexto marca failed")
check(tostring(registry.load(r2).error):find("estourou", 1, true) ~= nil, "motivo do estouro fica no run")

-- Caso 3: resposta vazia.
reply, overflow = "", false
local r3 = new_run("sem resposta")
check(worker.execute(r3) == false and registry.load(r3).status == "failed", "resposta vazia marca failed")

-- Caso 4: run morto pelo usuário não é sobrescrito pelo filho.
reply, overflow = "tarde demais", false
local r4 = new_run("morto antes")
local rec4 = registry.load(r4); rec4.status = "killed"; registry.save(rec4)
worker.execute(r4)
check(registry.load(r4).status == "killed", "filho não sobrescreve status killed")

-- Caso 5: parâmetros chegam ao contexto e ao loop.
reply, overflow = "ok", false
local r5 = new_run("verificar parâmetros")
worker.execute(r5)
local seen = registry.read_result(r5)
check(seen == "ok", "loop roda e grava a resposta")
check(last.input == "verificar parâmetros" and last.role == "user", "loop recebe a tarefa do run como usuário")
check(last.max == 3, "loop usa o MAX_ITER do contexto")
check(last.opts and last.opts.agent_id == "pesquisa" and last.opts.is_subagent == true
  and last.opts.run_id == r5, "contexto do filho recebe agente, flag de subagente e runId")

-- Caso 6: run inexistente.
local ok6, err6 = worker.execute("sub-naoexiste")
check(ok6 == false and tostring(err6):find("não encontrado", 1, true) ~= nil, "run inexistente é reportado")

-- Caso 7: eventos de início e fim ficam no log.
local tail = events.tail(r1, 5)
check(#tail >= 2 and tail[#tail]:find("final", 1, true) ~= nil, "log registra início e fim do run")

print(failures == 0 and "\nTODOS OS TESTES PASSARAM" or ("\n" .. failures .. " FALHA(S)"))
os.exit(failures == 0 and 0 or 1)
