-- tests/subagent_block_spec.lua — Bloco ao vivo dos subagentes (render, redesenho no lugar, acordar).
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
local block    = require("ui.subagent_block")
local subs     = require("tools.subagents")

local function run(id, status, agent, parent)
  registry.save({ runId = id, kind = "clone", agentId = agent or "main", task = "t", status = status,
    created_at = os.time(), parent_agent = parent or "main", cleanup = "keep",
    announce_consumed = false })
end

local function capture(fn)
  local buf, orig = {}, io.write
  io.write = function(...) for _, v in ipairs({ ... }) do buf[#buf + 1] = tostring(v) end end
  local ok, res = pcall(fn)
  io.write = orig
  assert(ok, res)
  return table.concat(buf), res
end

-- Sem subagentes: bloco vazio.
check(#block.render("main") == 0, "sem subagentes ativos, o bloco não tem linhas")

run("sub-aaa111", "running", "main")
run("sub-bbb222", "queued", "main")
run("sub-ccc333", "completed", "main")   -- terminado não aparece no bloco
run("sub-ddd444", "running", "other", "outro-pai")    -- de outro pai não aparece
events.append("sub-aaa111", "tool", "Read | arquivo.lua")
events.append("sub-aaa111", "tool", "Grep | foo")

local rows = block.render("main")
local joined = table.concat(rows, "\n")
check(#rows == 3, "cabeçalho + 2 subagentes do pai")
check(joined:find("1 ativo(s)", 1, true) ~= nil and joined:find("1 na fila", 1, true) ~= nil,
  "cabeçalho conta ativos e fila")
check(joined:find("sub-aaa111", 1, true) ~= nil and joined:find("Grep | foo", 1, true) ~= nil,
  "linha mostra a última ferramenta do subagente")
check(joined:find("aguardando na fila", 1, true) ~= nil, "subagente na fila mostra 'aguardando na fila'")
check(joined:find("sub-ccc333", 1, true) == nil and joined:find("sub-ddd444", 1, true) == nil,
  "terminados e de outro pai ficam fora do bloco")

-- Muitas linhas: limita a 5 e mostra o contador.
for i = 1, 7 do run(string.format("sub-e%03d", i), "queued", "main") end
local many = block.render("main")
check(table.concat(many, "\n"):find("… +", 1, true) ~= nil, "mais de 5 subagentes mostram '… +N'")

-- Redesenho: só escreve quando o conteúdo muda; sobe exatamente o número de linhas antigas.
block.finish()
local first = capture(function() block.refresh(rows, false) end)
check(first:find("\27[", 1, true) ~= nil and not first:match("\27%[%d+A"), "primeiro desenho não sobe o cursor")
local same = capture(function() block.refresh(rows, true, "P> ") end)
check(same == "", "mesmo conteúdo não redesenha")
local changed_rows = { rows[1], rows[2] }
local redraw = capture(function() block.refresh(changed_rows, true, "P> ") end)
check(redraw:find("\27[3A", 1, true) ~= nil, "redesenho sobe as 3 linhas do bloco antigo")
check(redraw:find("P> ", 1, true) ~= nil, "redesenho reimprime o prompt no fim")
check(block.drawn_lines() == 2, "contagem de linhas atualizada após redesenho")
block.finish()
check(block.drawn_lines() == 0, "finish zera o bloco para o próximo prompt")

-- Acordar: só quando há resultado terminado não anunciado para este pai.
local ctx = { agent_id = "main", msgs = {} }
for _, r in ipairs(registry.list()) do   -- terminados anteriores já foram entregues
  if r.status == "completed" then r.announce_consumed = true; registry.save(r) end
end
check(subs.has_pending(ctx) == false, "sem resultado pendente, não acorda")
run("sub-fff555", "completed", "main")
local rec = registry.load("sub-fff555"); rec.announce_consumed = false; registry.save(rec)
check(subs.has_pending(ctx) == true, "resultado terminado e não anunciado acorda o pai")
check(subs.has_pending({ agent_id = "outro", msgs = {} }) == false, "resultado de outro pai não acorda")

print(failures == 0 and "\nTODOS OS TESTES PASSARAM" or ("\n" .. failures .. " FALHA(S)"))
os.exit(failures == 0 and 0 or 1)
