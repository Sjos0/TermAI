-- tests/subagent_block_spec.lua — Subagentes na TUI como tool (issue #88):
-- uma linha ao iniciar, uma ao terminar, nada de tools do filho, nada que sobe o cursor,
-- não interrompe quem digita, não mostra o que já existia e mascara segredos.
package.path = "./?.lua;./?/init.lua;" .. package.path

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local root = "/tmp/termai_block_test_" .. tostring(os.time()) .. "_" .. tostring(math.random(100000))
os.execute("mkdir -p '" .. root .. "'")
require("tools.agents.paths").base_override = root

local registry = require("tools.subagents.registry")
local events   = require("tools.subagents.events")
local redact   = require("tools.subagents.redact")
local block    = require("ui.subagent_block")

local function run(id, status, task, parent, error_text)
  registry.save({ runId = id, kind = "clone", agentId = "main", task = task or "t", status = status,
    created_at = os.time(), parent_agent = parent or "main", cleanup = "keep",
    announce_consumed = false, error = error_text })
end

-- Captura tudo que o bloco escreve no terminal durante fn().
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

-- (0) Runs que já existiam antes da TUI abrir não são anunciados de novo.
run("sub-old001", "completed", "tarefa antiga", "main")
check(flush() == "", "runs que já existiam antes da TUI não são anunciados")

-- (1) Ao iniciar: uma linha amarela, com runId e tarefa.
run("sub-aaa111", "running", "Grep | foo")
local start = flush()
check(start:find("⬤", 1, true) and start:find("sub-aaa111", 1, true) and start:find("Grep | foo", 1, true),
      "início: linha amarela com runId e tarefa")
check(flush() == "", "início: não repete a mesma linha")

-- (2) Tools internas do filho não aparecem.
events.append("sub-aaa111", "tool", "Exec | curl -s https://api.github.com/repos")
events.append("sub-aaa111", "tool", "Read | README.md")
check(flush() == "", "tools internas do filho não geram linhas")

-- (3) Ao terminar: uma linha verde, uma única vez, sem cursor para cima.
run("sub-aaa111", "completed", "Grep | foo")
local done = flush()
check(done:find("✓", 1, true) and done:find("sub-aaa111", 1, true), "fim com sucesso: linha verde ✓")
check(flush() == "", "fim: não repete a linha de conclusão")

-- (4) Falha: linha vermelha com o motivo, e o segredo do motivo fica mascarado.
run("sub-bbb222", "failed", "tarefa", "main", "[ERRO] Falha apos 5 tentativas - token ghp_SECRET123")
local fail = flush()
check(fail:find("✗", 1, true) and fail:find("sub-bbb222", 1, true), "falha: linha vermelha ✗")
check(not fail:find("SECRET123", 1, true), "falha: segredo no motivo não aparece na tela")

-- (5) Só os runs do próprio pai.
run("sub-ccc333", "running", "outro pai", "outro")
check(flush() == "", "run de outro pai não aparece")

-- (6) Não interrompe quem está digitando: segura e mostra quando o campo esvaziar.
run("sub-ddd444", "running", "tarefa segura")
check(flush(false) == "", "com o usuário digitando, nada é escrito")
check(flush(true):find("sub-ddd444", 1, true) ~= nil, "campo vazio: a linha pendente aparece")

-- (7) Segredo na tarefa ou no comando é mascarado na tela e no log de eventos.
run("sub-eee555", "running", 'curl -H "Authorization: token ghp_SECRET999"')
local sec = flush()
check(not sec:find("SECRET999", 1, true), "segredo na tarefa não aparece na tela")
events.append("sub-eee555", "tool", 'Exec | curl -H "Authorization: token ghp_SECRET999"')
local logged = table.concat(events.tail("sub-eee555", 10), "\n")
check(not logged:find("SECRET999", 1, true), "segredo não é gravado no events.jsonl")

-- (8) Nunca sobe o cursor nem redesenha.
local cursor_up = false
for _, out in ipairs(all_output) do if out:find("\27%[%d*A") then cursor_up = true end end
check(not cursor_up, "nenhuma saída usa ESC[nA (cursor para cima)")

-- (9) Redação: padrões isolados.
check(redact.clean("Bearer abc123") == "Bearer ***", "redact: Bearer")
check(redact.clean("chave sk-ABCdef12") == "chave sk-***", "redact: sk-")
check(redact.clean("ola mundo") == "ola mundo", "redact: texto sem segredo fica igual")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
