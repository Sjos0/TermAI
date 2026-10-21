-- tests/subagents_command_spec.lua — Comando /subagents (list, info, log, kill, uso).
package.path = "./?.lua;./?/init.lua;" .. package.path

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local root = "/tmp/termai_subcmd_test_" .. tostring(os.time()) .. "_" .. tostring(math.random(100000))
os.execute("mkdir -p '" .. root .. "'")
require("tools.agents.paths").base_override = root

local registry = require("tools.subagents.registry")
local events   = require("tools.subagents.events")
local router   = require("agent.main_loop.commands_router.subagents")

-- Scheduler sem processos reais: nenhum run "running" fica vivo.
require("tools.subagents.launcher").exec.execute = function() return false end
require("tools.subagents.launcher").exec.popen = function() return { read = function() return "" end, close = function() end } end

local function capture(fn)
  local buf, orig = {}, io.write
  io.write = function(...) for _, v in ipairs({ ... }) do buf[#buf + 1] = tostring(v) end end
  local ok, res = pcall(fn)
  io.write = orig
  assert(ok, res)
  return table.concat(buf), res
end

registry.save({ runId = "sub-abc123", kind = "clone", agentId = "main", task = "pesquisar X",
  status = "completed", created_at = os.time(), parent_agent = "main", cleanup = "keep" })
events.append("sub-abc123", "tool", "Read | a.lua")
events.append("sub-abc123", "tool", "Grep | foo")

local out, res = capture(function() return router.route("/subagents", { cfg = {} }, 1) end)
check(out:find("sub-abc123", 1, true) ~= nil, "/subagents lista os runs")
check(type(res) == "table" and res.action == "continue", "comando de lista encerra o turno (action=continue)")

out = capture(function() router.route("/subagents info sub-abc123", { cfg = {} }, 1) end)
check(out:find("pesquisar X", 1, true) ~= nil, "/subagents info mostra a tarefa")

out = capture(function() router.route("/subagents log sub-abc123 1", { cfg = {} }, 1) end)
check(out:find("Grep", 1, true) ~= nil and out:find("Read", 1, true) == nil, "/subagents log com n mostra só as últimas linhas")

out = capture(function() router.route("/subagents info", { cfg = {} }, 1) end)
check(out:find("Uso:", 1, true) ~= nil, "/subagents info sem id mostra o uso")

out = capture(function() router.route("/subagents kill sub-abc123", { cfg = {} }, 1) end)
check(out:find("já terminado", 1, true) ~= nil, "matar run já terminado avisa, sem alterar")

out = capture(function() router.route("/subagents nada", { cfg = {} }, 1) end)
check(out:find("Uso:", 1, true) ~= nil, "subcomando desconhecido mostra o uso")

check(router.route("/status", { cfg = {} }, 1).action == nil, "outros comandos não são capturados")
check(router.route("/subagentsX", { cfg = {} }, 1).action == nil, "prefixo parecido não casa")

print(failures == 0 and "\nTODOS OS TESTES PASSARAM" or ("\n" .. failures .. " FALHA(S)"))
os.exit(failures == 0 and 0 or 1)
