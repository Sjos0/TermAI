-- tests/subagents_runtime_spec.lua — Runtime assíncrono de subagentes (fila, limites, anúncio, kill).
package.path = "./?.lua;./?/init.lua;" .. package.path
local portable_tmp = require("tests.helpers.tmp")

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local root = portable_tmp.name("termai_sub_test")
os.execute("mkdir -p '" .. root .. "'")
require("config.store").PATH = root .. "/config.json"
require("config.store")._data = nil
require("tools.agents.paths").base_override = root

local json      = require("json")
local registry  = require("tools.subagents.registry")
local launcher  = require("tools.subagents.launcher")
local scheduler = require("tools.subagents.scheduler")
local spawn     = require("tools.subagents.spawn")
local announce  = require("tools.subagents.announce")
local cleanup   = require("tools.subagents.cleanup")
local control   = require("tools.subagents.control")
local events    = require("tools.subagents.events")

-- Simulação do sistema: processos "vivos" e comandos de kill.
local alive, killed, next_pid = {}, {}, 4000
local run_of = {}   -- pid falso -> runId do worker (para a identidade do processo)
launcher.exec.popen = function(cmd)
  next_pid = next_pid + 1
  alive[next_pid] = true
  local pid = next_pid
  run_of[pid] = cmd:match("%-%-worker '([^']+)'")
  return { read = function() return tostring(pid) .. "\n" end, close = function() end }
end
-- Identidade do pid: PIDs falsos podem coincidir com processos reais no runner do CI.
-- Sem esta stub, /proc/<pid>/cmdline devolveria outro programa e o run viraria process_exit
-- (falha intermitente). Aqui o pid vivo sempre responde com a linha de comando do seu worker.
launcher.exec.cmdline = function(pid)
  if alive[pid] and run_of[pid] then return "lua5.4 main.lua run --worker " .. run_of[pid] end
  return nil
end
launcher.exec.execute = function(cmd)
  local p = cmd:match("kill %-0 (%d+)")
  if p then return alive[tonumber(p)] == true end
  local k = cmd:match("kill %-TERM (%d+)")
  if k then killed[tonumber(k)] = true; alive[tonumber(k)] = false end
  return true
end

local cfg = { agents = { defaults = { subagents = { maxConcurrent = 2, maxChildrenPerAgent = 3 } } } }
local parent = { agent_id = "main", cfg = cfg, msgs = {} }

local function spawn_run(task)
  return json.decode(spawn.spawn({ task = task }, parent))
end

local r1 = spawn_run("pesquisar A")
local r2 = spawn_run("pesquisar B")
local r3 = spawn_run("pesquisar C")
check(r1.status == "accepted" and r1.runId:match("^sub%-") ~= nil, "sessions_spawn responde accepted com runId")
check(registry.load(r1.runId).status == "running", "primeiro run inicia logo (há vaga)")
check(registry.load(r2.runId).status == "running", "segundo run também inicia (maxConcurrent=2)")
check(registry.load(r3.runId).status == "queued", "terceiro run fica na fila")
check(r3.state == "queued", "resposta do terceiro informa state=queued")

local refused = spawn.spawn({ task = "quarto" }, parent)
check(refused:match("maxChildrenPerAgent") ~= nil, "4º filho com 3 ativos é recusado por maxChildrenPerAgent")

check(spawn.spawn({ task = "x" }, { is_subagent = true, cfg = cfg }):match("profundidade") ~= nil,
  "subagente não pode criar subagente")
check(spawn.spawn({ task = "x", agentId = "nao_existe" }, parent):match("não existe") ~= nil,
  "agentId inexistente é recusado")
check(spawn.spawn({ task = "  " }, parent):match("obrigatório") ~= nil, "task vazia é recusada")

-- Conclui r1: o slot livre deve puxar o r3 da fila.
local rec1 = registry.load(r1.runId)
registry.write_result(r1.runId, "RESPOSTA DO RUN 1")
rec1.status, rec1.finished_at = "completed", os.time()
registry.save(rec1)
scheduler.tick(cfg)
check(registry.load(r3.runId).status == "running", "fila: o 3º inicia quando o 1º termina")

-- Anúncio ao pai: resultado entra no contexto uma vez.
local ctx = { agent_id = "main", msgs = {} }
check(announce.inject(ctx) >= 1, "anúncio injeta o run concluído")
local found = false
for _, m in ipairs(ctx.msgs) do
  if m.role == "system" and m.content:find("RESPOSTA DO RUN 1", 1, true) then found = true end
end
check(found, "resposta final chega ao contexto do pai")
check(announce.inject(ctx) == 0, "anúncio não repete na segunda passagem")

-- Retenção (issue #94): o padrão guarda o run entregue, para auditoria; delete explícito é coberto
-- em tests/subagents_retention_spec.lua.
check(cleanup.sweep() == 0 and registry.load(r1.runId) ~= nil, "padrão retém run entregue (sem apagar logo)")

-- Kill.
local kill_msg = control.matar({ runId = r2.runId })
check(kill_msg:match("^✓") ~= nil, "subagents_kill encerra o run")
check(registry.load(r2.runId).status == "killed" and killed[tonumber(registry.load(r2.runId).pid)], "run morto fica com status killed e processo sinalizado")

-- Processo morto sem terminar vira failed/process_exit.
local rec3 = registry.load(r3.runId)
alive[rec3.pid] = false
scheduler.tick(cfg)
local rec3b = registry.load(r3.runId)
check(rec3b.status == "failed" and rec3b.error == "process_exit", "processo que morreu vira failed/process_exit")

-- Timeout: run rodando além do limite é morto.
local slow = { runId = registry.new_id(), kind = "clone", agentId = "main", task = "lento",
  status = "running", pid = 4900, started_at = os.time() - 1000, timeout_seconds = 10,
  created_at = os.time(), parent_agent = "main", cleanup = "keep" }
registry.save(slow)
alive[4900] = true
scheduler.tick(cfg)
check(registry.load(slow.runId).status == "timeout" and killed[4900], "run que estoura runTimeoutSeconds é morto")

-- Eventos e listagem.
events.append(r2.runId, "tool", "Read | a.lua")
events.append(r2.runId, "tool", "Grep | foo")
local tail = events.tail(r2.runId, 1)
check(#tail == 1 and tail[1]:find("Grep", 1, true) ~= nil, "subagents_log mostra as últimas linhas")
check(control.listar({}):find(r2.runId, 1, true) ~= nil, "subagents_list lista os runs")
check(scheduler.limits(nil).maxChildrenPerAgent == 5 and scheduler.limits(nil).maxConcurrent == 5,
  "padrão de limites é 5 (simultâneos e por pai)")

print(failures == 0 and "\nTODOS OS TESTES PASSARAM" or ("\n" .. failures .. " FALHA(S)"))
os.exit(failures == 0 and 0 or 1)
