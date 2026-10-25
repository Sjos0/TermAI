-- tests/subagent_block_spec.lua — Avisos de subagente na TUI (contrato atual, estilo OpenClaw):
-- sem linha de lançamento; aviso de término uma única vez, pelo announce; sem tools do filho na tela;
-- nunca sobe o cursor; segredos mascarados.
package.path = "./?.lua;./?/init.lua;" .. package.path
local portable_tmp = require("tests.helpers.tmp")

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local root = portable_tmp.name("termai_block_test")
os.execute("mkdir -p '" .. root .. "'")
require("config.store").PATH = root .. "/config.json"
require("config.store")._data = nil
require("tools.agents.paths").base_override = root

local registry = require("tools.subagents.registry")
local events   = require("tools.subagents.events")
local block    = require("ui.subagent_block")
local announce = require("tools.subagents.announce")
local redact   = require("tools.subagents.redact")

local function capture(fn)
  local buf, orig = {}, io.write
  io.write = function(...) for _, v in ipairs({ ... }) do buf[#buf + 1] = tostring(v) end end
  local ok, res = pcall(fn)
  io.write = orig
  assert(ok, res)
  return table.concat(buf), res
end

local all = {}
local function save(id, status, parent, extra)
  local r = { runId = id, kind = "clone", agentId = "main", task = (extra and extra.task) or "tarefa",
    status = status, created_at = os.time() - 5, started_at = os.time() - 4,
    finished_at = (status ~= "running") and os.time() or nil,
    parent_agent = parent or "main", cleanup = "retain", announce_consumed = false, error = extra and extra.error }
  registry.save(r)
  if extra and extra.result then registry.write_result(id, extra.result) end
  return r
end

-- (1) Lançamento não escreve nada: o card da tool já mostra.
save("sub-d1", "running", "main")
local out1 = capture(function() return block.flush("main", true, nil) end)
check(out1 == "", "lançamento: nenhuma linha própria na TUI")

-- (2) Tools internas do filho não aparecem.
events.append("sub-d1", "tool", "Exec | curl -s https://example.invalid")
check(capture(function() return block.flush("main", true, nil) end) == "", "tools do filho não aparecem")

-- (3) Término: sai uma vez, pelo announce, com linha de sistema; nunca sobe o cursor.
local r2 = save("sub-d2", "completed", "main", { result = "RESULTADO-OK" })
local ctx = { agent_id = "main", msgs = {} }
local out3, n3 = capture(function() return announce.inject(ctx) end)
check(n3 == 1 and out3:find("sub-d2", 1, true) ~= nil and out3:find("concluído", 1, true) ~= nil,
  "término: aviso de sistema com runId e 'concluído'")
check(not out3:find("lançado", 1, true), "término: sem rótulo de origem")
local _, n3b = capture(function() return announce.inject(ctx) end)
check(n3b == 0, "término: o mesmo aviso não repete")
check(not out3:find("\27%[%d*A"), "término: nenhuma saída sobe o cursor (ESC[nA)")

-- (4) Falha com segredo no motivo: a tela não mostra o segredo.
save("sub-d3", "failed", "main", { error = "[ERRO] token ghp_SECRET77 falhou" })
local ctx2 = { agent_id = "main", msgs = {} }
local out4 = capture(function() return announce.inject(ctx2) end)
check(not out4:find("SECRET77", 1, true), "falha: segredo no motivo é mascarado na tela")
check(not require("ui.subagent_block").end_line(registry.load("sub-d3")):find("SECRET77", 1, true),
  "falha: segredo também sai mascarado na linha de término")

-- (5) Redação do texto de tarefa continua disponível.
check(redact.clean("Bearer abc123") == "Bearer ***", "redação: padrão Bearer continua mascarado")

os.execute("rm -rf '" .. root .. "'")
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
