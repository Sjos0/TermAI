-- tests/subagents_failures_spec/contexto.lua — fixtures e checagem compartilhadas pelas partes.
-- Carregado uma vez; o contador de falhas fica aqui (failures_count).
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

return {
  announce = announce,
  api = api,
  check = check,
  fresh_root = fresh_root,
  launcher = launcher,
  n_root = n_root,
  new_run = new_run,
  paths = paths,
  portable_tmp = portable_tmp,
  registry = registry,
  scheduler = scheduler,
  tmp = tmp,
  worker = worker,
  failures_count = function() return failures end,
}
