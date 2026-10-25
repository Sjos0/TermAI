package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- tests/subagents_lote2_spec.lua — lote 2 da paridade OpenClaw: send, steer, kill all, origem do spawn.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local portable_tmp = require("tests.helpers.tmp")

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local root = portable_tmp.name("termai_lote2_test")
os.execute("mkdir -p '" .. root .. "'")
require("tools.agents.paths").base_override = root

local registry  = require("tools.subagents.registry")
local inbox     = require("tools.subagents.inbox")
local control   = require("tools.subagents.control")
local subagents = require("tools.subagents")
local launcher  = require("tools.subagents.launcher")
control.tick = function() end
launcher.exec.execute = function() return true end
launcher.exec.cmdline = function() return nil end

local function run(id, o)
  registry.save({ runId = id, kind = "clone", agentId = "main", task = o.task or "tarefa",
    status = o.status or "running", created_at = os.time() - 5, started_at = os.time() - 4,
    finished_at = (o.status and o.status ~= "running") and os.time() or nil,
    parent_agent = o.parent or "main", parent_run = o.parent_run, depth = o.depth or 1,
    cleanup = "retain", announce_consumed = false, pid = o.pid })
end

-- (1) inbox: ordem, leitura incremental e rótulo de entrega no contexto do filho.
run("sub-a1", { status = "running" })
inbox.reset_offsets()
inbox.post("sub-a1", "message", "primeira")
inbox.post("sub-a1", "message", "segunda")
local first = inbox.read_new("sub-a1")
check(#first == 2 and first[1].text == "primeira" and first[2].text == "segunda", "inbox: lê as mensagens na ordem")
check(#inbox.read_new("sub-a1") == 0, "inbox: segunda leitura não repete o que já foi lido")

-- (2) Entrega pelo ponto seguro do filho (on_boundary), não só pela função isolada.
run("sub-a5", { status = "running" })
inbox.post("sub-a5", "redirect", "troque o foco para o parser")
local child_ctx = { is_subagent = true, run_id = "sub-a5", agent_id = "main", msgs = {} }
subagents.on_boundary(child_ctx)
local got = child_ctx.msgs[1] and child_ctx.msgs[1].content or ""
check(child_ctx.msgs[1] and child_ctx.msgs[1].role == "user", "filho: mensagem entregue como mensagem do usuário")
check(got:find("[redirecionamento do orquestrador]", 1, true) ~= nil and got:find("troque o foco", 1, true) ~= nil,
  "filho: redirecionamento chega com o rótulo de origem")
subagents.on_boundary(child_ctx)
check(#child_ctx.msgs == 1, "filho: a mesma mensagem não é entregue duas vezes")

-- (3) enviar: pai dono recebe; terminado recusa; estranho recusa; vazio recusa.
run("sub-a2", { status = "running", parent = "main" })
local parent_ctx = { agent_id = "main", msgs = {} }
check(control.enviar({ runId = "sub-a2", message = "oi" }, parent_ctx, "message"):find("entregue", 1, true) ~= nil,
  "enviar: pai dono envia mensagem a filho em execução")
check(control.enviar({ runId = "sub-a2", message = "oi" }, parent_ctx, "redirect"):find("redirecionamento", 1, true) ~= nil,
  "enviar: redirecionamento usa a confirmação de redirecionamento")
run("sub-a3", { status = "completed", parent = "main" })
check(control.enviar({ runId = "sub-a3", message = "oi" }, parent_ctx, "message"):find("já terminou", 1, true) ~= nil,
  "enviar: filho já terminado recusa a mensagem")
check(control.enviar({ runId = "sub-a2", message = "oi" }, { agent_id = "outro", msgs = {} }, "message"):find("não é um subagente seu", 1, true) ~= nil,
  "enviar: outro agente não fala com filho que não é dele")
check(control.enviar({ runId = "sub-a2", message = "  " }, parent_ctx, "message"):find("informe a mensagem", 1, true) ~= nil,
  "enviar: mensagem vazia é recusada")

-- (4) kill all: encerra os ativos do dono, não toca em outro dono nem em run já terminado.
run("sub-b1", { status = "running", parent = "main" })
run("sub-b2", { status = "queued", parent = "main" })
run("sub-b3", { status = "running", parent = "outro" })
run("sub-b4", { status = "completed", parent = "main" })
local msg = control.matar_todos(parent_ctx)
check(msg:find("5 subagente", 1, true) ~= nil, "kill all: encerra os 5 ativos do dono: sub-a1, sub-a2, sub-a5, sub-b1, sub-b2 (" .. msg .. ")")
check(registry.load("sub-b1").status == "killed" and registry.load("sub-b2").status == "killed",
  "kill all: ativos do dono ficam killed")
check(registry.load("sub-b3").status == "running", "kill all: não encerra subagente de outro agente")
check(registry.load("sub-b4").status == "completed", "kill all: não mexe em run já terminado")

os.execute("rm -rf '" .. root .. "'")
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
