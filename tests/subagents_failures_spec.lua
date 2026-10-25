-- tests/subagents_failures_spec.lua — Falhas de subagentes: requisição esgotada, stream cortado,
-- PID reaproveitado, deadline do SO e retomada depois que o orquestrador morre.
package.path = "./?.lua;./?/init.lua;" .. package.path
local portable_tmp = require("tests.helpers.tmp")

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local tmp = portable_tmp.name("termai_subfail")
os.execute("mkdir -p '" .. tmp .. "'")
require("config.store").PATH = tmp .. "/config.json"
require("config.store")._data = nil
local paths = require("tools.agents.paths")
local n_root = 0
local function fresh_root()
  n_root = n_root + 1
  paths.base_override = tmp .. "/r" .. n_root
  os.execute("mkdir -p '" .. paths.base_override .. "'")
end

local registry  = require("tools.subagents.registry")
local launcher  = require("tools.subagents.launcher")
local scheduler = require("tools.subagents.scheduler")
local announce  = require("tools.subagents.announce")
local worker    = require("tools.subagents.worker")
local api       = require("agent.api")

local function new_run(extra)
  local rec = { runId = registry.new_id(), agentId = "main", parent_agent = "main", kind = "clone",
                task = "tarefa", status = "queued", created_at = os.time() }
  for k, v in pairs(extra or {}) do rec[k] = v end
  assert(registry.save(rec), "falha ao gravar run de teste")
  return rec.runId
end

-- O filho monta o contexto via context.build: aqui, um contexto mínimo sem provedor real.
package.loaded["agent.context"] = { build = function()
  return { is_subagent = true, msgs = {}, MAX_ITER = 3, cfg = { agents = { defaults = {} } }, run_id = "x" }
end }

-- (1) Requisição esgotou as tentativas: o filho NÃO pode terminar como completed.
fresh_root()
api.pensar_stream = function() return "[ERRO] Falha apos 5 tentativas - Sem resposta do servidor", false, nil, "" end
local id1 = new_run({ status = "running" })
local ok1 = worker.execute(id1)
local r1 = registry.load(id1)
check(ok1 == false, "requisição esgotada: worker.execute retorna false")
check(r1.status == "failed", "requisição esgotada: status failed (veio " .. tostring(r1.status) .. ")")
check(tostring(r1.error):find("Falha apos 5 tentativas", 1, true) ~= nil, "requisição esgotada: error carrega o motivo")

-- (2) Stream cortado no meio: falha marcada como parcial, com o texto parcial preservado.
fresh_root()
api.pensar_stream = function() return "resposta pela meta", false, false, "" end
local id2 = new_run({ status = "running" })
worker.execute(id2)
local r2 = registry.load(id2)
check(r2.status == "failed", "stream cortado: status failed (veio " .. tostring(r2.status) .. ")")
check(r2.partial == true, "stream cortado: run marcado como partial")
check(registry.read_result(id2) == "resposta pela meta", "stream cortado: texto parcial preservado em result.txt")
check(tostring(r2.error):find("incompleta", 1, true) ~= nil, "stream cortado: error explica que a resposta ficou incompleta")

-- (2b) Sanidade: resposta normal continua completed.
fresh_root()
api.pensar_stream = function() return "PONG", false, true, "" end
local id3 = new_run({ status = "running" })
local ok3 = worker.execute(id3)
check(ok3 == true and registry.load(id3).status == "completed" and registry.read_result(id3) == "PONG",
      "resposta normal continua completed")

-- (3) PID reaproveitado por outro programa não conta como vivo e não recebe kill.
local sent = {}
launcher.exec.execute = function(cmd) sent[#sent + 1] = cmd; return true end
launcher.exec.cmdline = function() return "/usr/bin/python3 outro-programa" end
check(launcher.alive(777, "sub-abc") == false, "PID reaproveitado: não conta como vivo")
sent = {}
launcher.kill(777, "sub-abc")
local signaled = false
for _, c in ipairs(sent) do if c:find("kill -TERM", 1, true) then signaled = true end end
check(not signaled, "PID reaproveitado: kill não sinaliza o outro programa")
launcher.exec.cmdline = function() return "lua5.4 /x/main.lua run --worker sub-abc" end
check(launcher.alive(777, "sub-abc") == true, "PID do próprio worker conta como vivo")
launcher.exec.cmdline = function() return nil end
check(launcher.alive(777, "sub-abc") == true, "identidade ilegível: mantém o kill -0 de antes")

-- (4) O filho sobe sob o deadline do sistema (timeout), mesmo que o pai morra.
local cmds = {}
launcher.exec.popen = function(cmd)
  cmds[#cmds + 1] = cmd
  return { read = function() return "4242\n" end, close = function() end }
end
launcher.exec.execute = function() return true end
launcher._has_timeout = nil
local pid = launcher.start("sub-abc1", 600)
check(pid == 4242, "start devolve o pid")
check(cmds[1]:find("timeout", 1, true) ~= nil and cmds[1]:find("630", 1, true) ~= nil,
      "start aplica deadline do SO (600s + 30s de folga)")
launcher.exec.execute = function(cmd)
  if cmd:find("command -v timeout", 1, true) then return false end
  return true
end
launcher._has_timeout = nil
cmds = {}
launcher.start("sub-abc2", 600)
check(cmds[1]:find("timeout", 1, true) == nil, "sem o comando timeout no sistema: sobe sem ele")

-- (5) Orquestrador morreu: o estado persiste e a retomada é correta e idempotente.
fresh_root()
launcher.exec.execute = function() return false end   -- nenhum pid vivo
launcher.exec.cmdline = function() return nil end
local ida = new_run({ status = "completed", finished_at = os.time(), announce_pending = true })
registry.write_result(ida, "RESULTADO-A")
local idb = new_run({ status = "running", pid = 5555, started_at = os.time() - 5, timeout_seconds = 600 })
scheduler.tick({})
check(registry.load(idb).status == "failed" and registry.load(idb).error == "process_exit",
      "pid morto antes do prazo: failed/process_exit")
local ctx = { agent_id = "main", msgs = {} }
local n1 = announce.inject(ctx)
local n2 = announce.inject(ctx)
check(n1 == 2 and n2 == 0, "anúncio entrega cada run uma única vez (1ª=" .. n1 .. ", 2ª=" .. n2 .. ")")

-- (5b) run.json corrompido não derruba listagem nem anúncio.
fresh_root()
os.execute("mkdir -p '" .. registry.base() .. "/sub-deadbeef'")
local f = io.open(registry.base() .. "/sub-deadbeef/run.json", "w"); f:write("{ isto nao e json"); f:close()
local okc, errc = pcall(function() registry.list(); announce.inject({ agent_id = "main", msgs = {} }) end)
check(okc, "run.json corrompido não derruba list/inject" .. (okc and "" or (": " .. tostring(errc))))

-- (6) O anúncio de falha diz o motivo, entrega o parcial e orienta o orquestrador.
fresh_root()
local idp = new_run({ status = "failed", partial = true, error = "resposta incompleta (stream cortado)",
                      finished_at = os.time() })
registry.write_result(idp, "TEXTO-PARCIAL")
local pctx = { agent_id = "main", msgs = {} }
announce.inject(pctx)
local msg = pctx.msgs[1] and pctx.msgs[1].content or ""
check(msg:find("resposta incompleta", 1, true) ~= nil, "anúncio de falha inclui o motivo")
check(msg:find("TEXTO-PARCIAL", 1, true) ~= nil, "anúncio de falha inclui o resultado parcial")
check(msg:find("NÃO foi concluído", 1, true) ~= nil, "anúncio de falha avisa que o trabalho não foi concluído")

-- (7) Tentativas de requisição do filho viram eventos; o pai não grava nada.
fresh_root()
local events = require("tools.subagents.events")
local idr = new_run({ status = "running" })
events.retry({ is_subagent = true, run_id = idr }, 2, 5, "HTTP 429", 8)
events.retry({ run_id = idr }, 3, 5, "ignorado", 8)
local tail = events.tail(idr, 10)
check(#tail == 1 and tail[1]:find("2/5", 1, true) and tail[1]:find("HTTP 429", 1, true),
      "retry do filho vira evento e o pai não grava")

os.execute("rm -rf '" .. tmp .. "'")
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
