-- tests/subagents_mvp_spec.lua — Sanidade do MVP de subagentes (#81).
package.path = "./?.lua;./?/init.lua;" .. package.path

local failures = 0
local function assert_true(cond, msg)
  if not cond then
    failures = failures + 1
    print("FAIL: " .. tostring(msg))
  else
    print("OK:   " .. tostring(msg))
  end
end

local gen = require("session.generate")
local id = gen.id()
local key = gen.key()
assert_true(id:match("^TUI:main:[0-9a-f]+$") ~= nil, "generate.id() default TUI:main:hex")
assert_true(key == "TUI:main", "generate.key() default TUI:main")
local id2 = gen.id("agent", "coder")
assert_true(id2:match("^agent:coder:[0-9a-f]+$") ~= nil, "generate.id(role,prefix) parametrizado")

local tools = require("tools")
assert_true(tools.registry.sessions_spawn ~= nil, "registry sessions_spawn")
assert_true(tools.registry.subagents_listar ~= nil, "registry subagents_listar")
assert_true(tools.registry.subagents_status ~= nil, "registry subagents_status")
assert_true(tools.registry.subagents_wait ~= nil, "registry subagents_wait")
assert_true(tools.registry.sessoes_listar ~= nil, "sessoes_listar intacta")

local policy = require("tools.subagents.policy")
local ok_self = policy.is_agent_allowed("main", "main", { agents = { defaults = {} } })
assert_true(ok_self, "allow próprio id")
local ok_other, reason = policy.is_agent_allowed("main", "other", { agents = { defaults = {} } })
assert_true(not ok_other, "nega agentId estrangeiro: " .. tostring(reason))
local ok_star = policy.is_agent_allowed("main", "other", {
  agents = { defaults = { subagents = { allowAgents = { "*" } } } }
})
assert_true(ok_star, "allowAgents * permite qualquer")

local spawn = require("tools.subagents.spawn")
local store = require("tools.subagents.store")
local json = require("json")

local parent_ctx = {
  agent_id = "main",
  cfg = {
    agents = {
      defaults = {
        model = { primary = "" },
        subagents = { maxConcurrent = 2, maxChildrenPerAgent = 3 },
      },
      list = { { id = "main" } },
    },
  },
  is_subagent = false,
}

local out = spawn.spawn({ task = "diga oi" }, parent_ctx)
local okj, payload = pcall(json.decode, out)
assert_true(okj and payload.runId ~= nil, "spawn retorna runId JSON: " .. tostring(out))
assert_true(payload.status == "queued" or payload.status == "running", "status inicial")
assert_true(payload.childSessionKey:match("^agent:main:subagent:") ~= nil, "childSessionKey namespace")

local found = false
for _, r in ipairs(store.list()) do
  if r.runId == payload.runId then found = true end
end
assert_true(found, "run aparece em store.list")

local bad = spawn.spawn({ task = "x", agentId = "ghost" }, parent_ctx)
assert_true(type(bad) == "string" and bad:match("policy") ~= nil, "spawn estrangeiro falha policy")

local child_ctx = { agent_id = "main", is_subagent = true, cfg = parent_ctx.cfg }
local depth = spawn.spawn({ task = "x" }, child_ctx)
assert_true(type(depth) == "string" and depth:match("depth") ~= nil, "filho não spawna")

local dset = policy.child_disabled_set("main")
assert_true(dset.sessions_spawn == true, "denylist sessions_spawn")
assert_true(dset.sessoes_listar == true, "denylist sessoes_listar")

local scheduler = require("tools.subagents.scheduler")
local r = store.get(payload.runId)
if r then r.status = "running"; store.upsert(r) end
scheduler.reconcile_orphans()
r = store.get(payload.runId)
assert_true(r and r.status == "failed" and r.error == "process_exit", "orphan → failed process_exit")

print("\n==== Resultado: " .. (failures == 0 and "PASS" or ("FAIL x" .. failures)) .. " ====")
os.exit(failures == 0 and 0 or 1)
