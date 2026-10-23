-- tests/subagents_info_card_spec.lua — subagents_info no formato OpenClaw (cartão, redação, truncamento).
package.path = "./?.lua;./?/init.lua;" .. package.path

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local root = "/tmp/termai_card_test_" .. tostring(os.time()) .. "_" .. tostring(math.random(100000))
os.execute("mkdir -p '" .. root .. "'")
require("config.store").PATH = root .. "/config.json"
require("config.store")._data = nil
require("tools.agents.paths").base_override = root

local registry = require("tools.subagents.registry")
local control  = require("tools.subagents.control")
local card     = require("tools.subagents.card")
local function info(args) return (control.info(args):gsub("%s+", " ")) end
control.tick = function() end

local function run(id, o)
  registry.save({ runId = id, kind = "clone", agentId = "main", task = o.task or "tarefa",
    status = o.status, created_at = os.time() - 60, started_at = os.time() - 50,
    finished_at = o.status ~= "running" and os.time() - 5 or nil,
    parent_agent = "main", cleanup = o.cleanup or "retain", announce_consumed = o.consumed or false,
    error = o.error, error_class = o.error_class, partial = o.partial, timeout_seconds = 600 })
  if o.result then registry.write_result(id, o.result) end
  if o.events then
    local f = io.open(registry.dir(id) .. "/events.jsonl", "w")
    f:write('{"t":1,"kind":"tool","text":"Read | a.md"}\n{"t":2,"kind":"tool","text":"Grep | x"}\n')
    f:close()
  end
end

-- (1) Concluído: cartão com status, resultado e limpeza; sem seção de progresso.
run("sub-e1", { status = "completed", result = "RESULTADO-OK" })
local c1 = info({ runId = "sub-e1" })
check(c1:find("Status: completed", 1, true) ~= nil, "cartão: status completed")
check(c1:find("RESULTADO-OK", 1, true) ~= nil, "cartão: traz o resultado")
check(c1:find("Limpeza: retain", 1, true) ~= nil, "cartão: traz a política de limpeza")
check(c1:find("Progresso:", 1, true) == nil, "cartão: run concluído não tem progresso")
check(c1:find("Tokens:", 1, true) ~= nil, "cartão: declara que tokens não são registrados (sem inventar número)")

-- (2) Falhou: erro com classe, segredo redigido na tela.
run("sub-e2", { status = "failed", error_class = "network",
  error = "[ERRO] Falha apos 5 tentativas - Sem resposta do servidor token ghp_SECRET9" })
local c2 = info({ runId = "sub-e2" })
check(c2:find("Status: failed", 1, true) ~= nil and c2:find("network", 1, true) ~= nil, "cartão: falha com classe do erro")
check(not c2:find("SECRET9", 1, true), "cartão: segredo no erro é redigido")

-- (3) Prazo estourado com parcial: nome 'timed out' e nota sobre o parcial.
run("sub-e3", { status = "timeout", partial = true, error_class = "timeout", error = "runTimeoutSeconds excedido",
  result = "TRABALHO-ATE-O-KILL" })
local c3 = info({ runId = "sub-e3" })
check(c3:find("Status: timed out", 1, true) ~= nil, "cartão: timeout aparece como 'timed out' (nome do OpenClaw)")
check(c3:find("Notes: resultado parcial", 1, true) ~= nil, "cartão: nota sinaliza o resultado parcial")
check(c3:find("TRABALHO-ATE-O-KILL", 1, true) ~= nil, "cartão: traz o parcial salvo")

-- (4) Em execução: progresso com tools usadas e o último evento.
run("sub-e4", { status = "running", events = true })
local c4 = info({ runId = "sub-e4" })
check(c4:find("Progresso:", 1, true) ~= nil and c4:find("tools=2", 1, true) ~= nil, "cartão: run em execução mostra progresso e tools")
check(c4:find("Status: running", 1, true) ~= nil, "cartão: status running")

-- (5) Na fila.
run("sub-e5", { status = "queued" })
check(info({ runId = "sub-e5" }):find("Status: queued", 1, true) ~= nil, "cartão: status queued")

-- (6) Resultado longo: truncado com sinalizador de bytes, sem estourar a janela.
run("sub-e6", { status = "completed", result = string.rep("á", 3000) })
local c6 = info({ runId = "sub-e6" })
check(c6:find("[truncado:", 1, true) ~= nil, "resultado longo: sinaliza truncamento")
local line6 = c6:match("Resultado: ([^\n]*)") or ""
check(#line6 < 1400, "resultado longo: prévia limitada (" .. #line6 .. " bytes na linha)")
check(utf8.len(c6) ~= nil, "resultado longo: corte preserva UTF-8")

-- (7) Tarefa com segredo: mascarada.
run("sub-e7", { status = "completed", task = 'curl -H "Authorization: token ghp_SECRET7"', result = "ok" })
check(not info({ runId = "sub-e7" }):find("SECRET7", 1, true), "tarefa com segredo: mascarada no cartão")

-- (8) Run que não existe: status unknown, sem erro cru.
local c8 = info({ runId = "sub-ff" })
check(c8:find("Status: unknown", 1, true) ~= nil, "run inexistente: status unknown")

-- (9) formato=json: registro redigido, ainda JSON válido com runId.
local j = info({ runId = "sub-e7", formato = "json" })
check(j:find('"runId"', 1, true) ~= nil and not j:find("SECRET7", 1, true), "formato json: registro redigido")

-- (10) Função pura: o cartão não depende do disco.
check(card.build({ runId = "sub-p1", status = "completed", task = "t", agentId = "main", parent_agent = "main",
  cleanup = "retain" }, { result = "x" }):find("Subagente sub-p1", 1, true) ~= nil, "card.build é puro e funciona sem disco")

os.execute("rm -rf '" .. root .. "'")
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
