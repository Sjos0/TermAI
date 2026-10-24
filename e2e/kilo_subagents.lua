package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- e2e/kilo_subagents.lua — Subagentes reais com Kilo: clone, agente independente e fila (2 simultâneos).
package.path = "./?.lua;./?/init.lua;" .. package.path
local json      = require("json")
local config    = require("config")
local log       = require("diag.log")
local registry  = require("tools.subagents.registry")
local scheduler = require("tools.subagents.scheduler")
local spawn     = require("tools.subagents.spawn")
local announce  = require("tools.subagents.announce")
local create    = require("tools.agents.create")
require("e2e.common").ensure_kilo()

local MODEL     = "kilo/kilo-auto/free"
local out_dir   = os.getenv("E2E_OUT") or "/tmp/termai-e2e"
local TIMEOUT_S = 900
os.execute(string.format("mkdir -p '%s'", out_dir))

config.set("agents.defaults.model.primary", MODEL)
config.set("agents.defaults.subagents.maxConcurrent", 2)
config.set("agents.defaults.subagents.maxChildrenPerAgent", 5)
config.set("agents.defaults.subagents.runTimeoutSeconds", 600)

-- Papel do usuário: cria o agente independente (confirmed=true).
local created = create.create({ id = "pesquisa", name = "Pesquisador",
   identity = "Responde de forma curta e exata.",
  functions = "Responder exatamente o que for pedido, sem texto extra.", confirmed = true })
log.info("e2e_agent_created", { result = created })

local parent = { agent_id = "main", cfg = config.load(), msgs = {} }
local tasks = {
  { label = "clone",   args = { task = "Responda apenas com a palavra CLONE_OK.", cleanup = "keep" }, token = "CLONE_OK" },
  { label = "agente",  args = { task = "Responda apenas com a palavra AGENTE_OK.", agentId = "pesquisa", cleanup = "keep" }, token = "AGENTE_OK" },
  { label = "fila",    args = { task = "Responda apenas com a palavra FILA_OK.", cleanup = "keep" }, token = "FILA_OK" },
}

local runs, accepted_all = {}, true
for _, t in ipairs(tasks) do
  local res = json.decode(spawn.spawn(t.args, parent))
  t.run_id = res and res.runId
  if not t.run_id then accepted_all = false end
  log.info("e2e_spawn", { label = t.label, run_id = t.run_id, state = res and res.state, raw = tostring(res) })
  runs[#runs + 1] = t
end

local max_running, max_child_rss = 0, 0
local started = os.time()
local all_done = false
while os.time() - started < TIMEOUT_S do
  scheduler.tick(parent.cfg)
  local running, done = 0, 0
  for _, t in ipairs(runs) do
    local rec = t.run_id and registry.load(t.run_id)
    if rec then
      if rec.status == "running" then
        running = running + 1
        local rss = log.rss_kb(rec.pid) or 0
        if rss > max_child_rss then max_child_rss = rss end
      end
      if scheduler.is_terminal(rec) then done = done + 1 end
    end
  end
  if running > max_running then max_running = running end
  if done == #runs then all_done = true; break end
  os.execute("sleep 2")
end

-- Entrega ao pai (como o loop faria no ponto seguro) e relatório antes da limpeza.
local delivered = announce.inject(parent)
local summary = { model = MODEL, accepted = accepted_all, all_done = all_done,
  delivered = delivered, max_running_observed = max_running,
  max_child_rss_kb = max_child_rss, runs = {} }
local all_ok = accepted_all and all_done
for _, t in ipairs(runs) do
  local rec = t.run_id and registry.load(t.run_id) or {}
  local result = (t.run_id and registry.read_result(t.run_id)) or ""
  local token_ok = result:upper():find(t.token, 1, true) ~= nil
  if rec.status ~= "completed" or not token_ok then all_ok = false end
  summary.runs[#summary.runs + 1] = { label = t.label, run_id = t.run_id, status = rec.status,
    error = rec.error, agent = rec.agentId, token = t.token, token_ok = token_ok,
    result_chars = #result, result_head = result:sub(1, 120),
    duration_s = (rec.finished_at and rec.started_at) and (rec.finished_at - rec.started_at) or nil }
end
summary.passed = all_ok
local f = io.open(out_dir .. "/subagents.json", "w")
f:write(json.encode(summary)); f:close()
log.info("e2e_subagents_done", { passed = all_ok, max_running = max_running, max_child_rss_kb = max_child_rss })

print(all_ok and "SUBAGENTES OK" or "SUBAGENTES FALHARAM (ver subagents.json)")
os.exit(all_ok and 0 or 1)
