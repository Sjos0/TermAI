-- tests/subagent_block_spec.lua — Subagentes na TUI (issues #88 e aviso ao pai):
-- amarela ao LANÇAR; verde/vermelha só junto com o AVISO ao pai (uma vez); nada antes disso;
-- não interrompe quem digita; não mostra tools do filho; sem ESC[nA; mascara segredos.
package.path = "./?.lua;./?/init.lua;" .. package.path

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local root = "/tmp/termai_block_test_" .. tostring(os.time()) .. "_" .. tostring(math.random(100000))
os.execute("mkdir -p '" .. root .. "'")
require("tools.agents.paths").base_override = root

local registry  = require("tools.subagents.registry")
local events    = require("tools.subagents.events")
local redact    = require("tools.subagents.redact")
local block     = require("ui.subagent_block")
local subagents = require("tools.subagents")
local announce  = require("tools.subagents.announce")

local function run(id, status, task, parent, error_text)
  registry.save({ runId = id, kind = "clone", agentId = "main", task = task or "t", status = status,
    created_at = os.time(), parent_agent = parent or "main", cleanup = "keep",
    announce_consumed = false, error = error_text })
end

-- Captura tudo que fn escreve no terminal.
local function capture(fn)
  local buf, orig = {}, io.write
  io.write = function(...) for _, v in ipairs({ ... }) do buf[#buf + 1] = tostring(v) end end
  local ok, res = pcall(fn)
  io.write = orig
  assert(ok, res)
  return table.concat(buf), res
end

local all_output = {}
local function flush(buffer_empty)
  local out = capture(function() block.flush("main", buffer_empty == nil and true or buffer_empty, nil) end)
  all_output[#all_output + 1] = out
  return out
end
local function aviso(ctx)
  local out, n = capture(function() return announce.inject(ctx) end)
  all_output[#all_output + 1] = out
  return out, n
end

-- (0) Runs que já existiam antes da TUI abrir não são anunciados.
run("sub-old001", "completed", "tarefa antiga", "main")
check(flush() == "", "runs que já existiam antes da TUI não são anunciados")

-- (1) Ao LANÇAR: uma linha amarela, uma única vez.
run("sub-aaa111", "running", "Grep | foo")
local start = flush()
check(start:find("⬤", 1, true) and start:find("sub-aaa111", 1, true) and start:find("lançado pelo orquestrador", 1, true),
      "lançamento: linha amarela com runId e 'lançado pelo orquestrador'")
check(flush() == "", "lançamento: não repete a linha")

-- (2) O filho TERMINA, mas o pai ainda não foi acordado: NADA é impresso (sem verde antecipado).
run("sub-aaa111", "completed", "Grep | foo")
check(flush() == "", "término sem aviso: nenhuma linha verde antes do pai ser acordado")
check(subagents.has_pending({ agent_id = "main" }), "término sem aviso: o pai continua marcado como pendente")

-- (3) Tools internas do filho não aparecem.
events.append("sub-aaa111", "tool", "Exec | curl -s https://api.github.com/repos")
check(flush() == "", "tools internas do filho não geram linhas")

-- (4) Quem digita não é interrompido: nada é escrito, a pendência fica.
run("sub-ddd444", "running", "tarefa segura")
check(flush(false) == "", "com o usuário digitando, nada é escrito")
check(flush(true):find("sub-ddd444", 1, true) ~= nil, "campo vazio: a amarela pendente aparece")

-- (5) AVISO ao pai: a linha verde sai aqui, com o mesmo estilo, e o resultado entra no contexto.
local ctx = { agent_id = "main", msgs = {} }
local out, n = aviso(ctx)
check(n == 1, "aviso entrega o run concluído (1)")
check(out:find("⬤", 1, true) and out:find("sub-aaa111", 1, true) and out:find("concluído", 1, true),
      "aviso: linha verde ⬤ com runId e 'concluído'")
check(#ctx.msgs == 1 and ctx.msgs[1].role == "system", "aviso: resultado entra no contexto do pai")
check(not subagents.has_pending(ctx), "aviso: pai deixa de estar pendente")
local out2, n2 = aviso(ctx)
check(n2 == 0 and out2 == "", "aviso: o mesmo run não é anunciado de novo")

-- (6) Falha: aviso em vermelho com o motivo, segredo mascarado.
run("sub-bbb222", "failed", "tarefa", "main", "[ERRO] Falha apos 5 tentativas - token ghp_SECRET123")
local ctx2 = { agent_id = "main", msgs = {} }
local fout = aviso(ctx2)
check(fout:find("sub-bbb222", 1, true) and fout:find("Falha apos 5", 1, true), "falha: aviso vermelho com o motivo")
check(not fout:find("SECRET123", 1, true), "falha: segredo no motivo não aparece na tela")

-- (7) Só os runs do próprio pai.
run("sub-ccc333", "completed", "outro pai", "outro")
check(subagents.has_pending({ agent_id = "outro" }), "o outro pai é notificado do próprio run")
check(not subagents.has_pending({ agent_id = "main" }), "a pendência do outro pai não acorda o main")
local ctx3 = { agent_id = "main", msgs = {} }
local _, n3 = aviso(ctx3)
check(n3 == 0, "aviso não entrega run de outro pai")

-- (8) Segredo na tarefa ou no log é mascarado.
run("sub-eee555", "running", 'curl -H "Authorization: token ghp_SECRET999"')
local sec = flush()
check(not sec:find("SECRET999", 1, true), "segredo na tarefa não aparece na tela")
events.append("sub-eee555", "tool", 'Exec | curl -H "Authorization: token ghp_SECRET999"')
local logged = table.concat(events.tail("sub-eee555", 10), "\n")
check(not logged:find("SECRET999", 1, true), "segredo não é gravado no events.jsonl")

-- (9) Nunca sobe o cursor nem redesenha.
local cursor_up = false
for _, o in ipairs(all_output) do if o:find("\27%[%d*A") then cursor_up = true end end
check(not cursor_up, "nenhuma saída usa ESC[nA (cursor para cima)")

-- (10) Redação: padrões isolados.
check(redact.clean("Bearer abc123") == "Bearer ***", "redact: Bearer")
check(redact.clean("chave sk-ABCdef12") == "chave sk-***", "redact: sk-")
check(redact.clean("ola mundo") == "ola mundo", "redact: texto sem segredo fica igual")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
