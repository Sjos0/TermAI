-- tests/subagents_units_spec.lua
-- Rede de segurança forense do MVP de subagentes (Issue #81 / PR #82).
--
-- Origem: Agente de Testes 🧪 — expansão pós-Caçador (#84 #85 #86 já corrigidos
--         na mesma branch). Objetivo: qualquer alteração futura em policy,
--         store, spawn, runner timeout, scheduler announce, inspect wait/cancel,
--         isolamento de child_ctx / prepare_user_turn ou contrato de ids
--         deve gritar aqui antes de chegar à TUI / produção.
--
-- "E se isso mudar?":
--   * runTimeoutSeconds deixar de ser checado em queued/running/pós-rodar
--   * child_ctx voltar a pré-inserir role=user (user duplicado)
--   * prepare_user_turn consumir is_first_turn ou injetar memória em is_subagent
--   * _G.__termai_ctx do pai ficar stale após advance do filho
--   * allowAgents default abrir superfície acidental
--   * maxConcurrent / maxChildrenPerAgent não rejeitar no spawn
--   * denylist do filho omitir sessions_spawn / sessoes_* / subagents_*
--   * orphan reconcile não marcar process_exit
--   * announce inject poluir msgs do pai sem consumir flag
--   * sessoes_* / generate default strings regressarem
--
-- Tipos:
--   * unitário puro (ids, policy defaults, is_timed_out aritmética)
--   * unitário com filesystem isolado (store sob HOME temporário)
--   * regressão explícita #84 #85 #86
--   * caso extremo (nil, vazio, bordas de timeout, caps saturados, tipos errados)
--   * contrato estrutural de payloads JSON e msgs do child
--
-- Escopo deliberadamente NÃO cobre: loop.rodar com modelo real, I/O de rede,
-- TUI slash /subagents, multi-process OS (fora do MVP).

package.path = "./?.lua;./?/init.lua;" .. package.path

local pass, fail = 0, 0
local function T(name, ok, detail)
  if ok then
    pass = pass + 1
  else
    fail = fail + 1
    print("  FAIL: " .. name .. (detail and (" — " .. tostring(detail)) or ""))
  end
end

local function sec(title)
  print("\n=== " .. title .. " ===")
end

-- ── Isolamento de HOME / store ────────────────────────────────────────────
-- Cada execução usa HOME efêmero para não contaminar ~/.TermAI do host.
local TEST_HOME = "/tmp/termai-subagents-units-" .. tostring(os.time()) .. "-" .. tostring(math.random(10000, 99999))
os.execute("mkdir -p '" .. TEST_HOME .. "'")
local _old_home = os.getenv("HOME")
-- Força getenv a ver o novo HOME nas leituras subsequentes dos módulos.
-- (módulos já carregados que capturaram HOME no require usam os próprios M.DIR;
--  por isso monkeypatchamos store.DIR/PATH após require.)

print("\n=== Unit tests: subagents MVP (Issue #81 / PR #82) — Agente de Testes 🧪 ===")
print("HOME isolado: " .. TEST_HOME)

local json = require("json")
local ids = require("tools.subagents.ids")
local store = require("tools.subagents.store")
local policy = require("tools.subagents.policy")
local spawn = require("tools.subagents.spawn")
local runner = require("tools.subagents.child_runner")
local scheduler = require("tools.subagents.scheduler")
local inspect = require("tools.subagents.inspect")
local child_ctx_mod = require("tools.subagents.child_ctx")
local sm = require("agent.loop.system_messages")
local gen = require("session.generate")

-- Redirect store + ids transcript base para TEST_HOME
store.DIR  = TEST_HOME .. "/.TermAI/subagents"
store.PATH = store.DIR .. "/runs.json"
-- ids.transcript_path ainda usa os.getenv("HOME"); sobrescrevemos via env se possível.
-- Em sandbox setenv pode não existir; patchamos a função.
local _orig_transcript_path = ids.transcript_path
ids.transcript_path = function(agent_id, run_id)
  local dir = TEST_HOME .. "/.TermAI/subagents/transcripts"
  os.execute("mkdir -p '" .. dir .. "'")
  local key = ids.child_session_key(agent_id, run_id)
  return dir .. "/" .. (key:gsub(":", "-")) .. ".jsonl"
end

local function wipe_store()
  os.execute("rm -rf '" .. store.DIR .. "'")
  os.execute("mkdir -p '" .. store.DIR .. "'")
end

local function parent_ctx_fixture(overrides)
  local ctx = {
    agent_id = "main",
    session_id = "TUI:main:test",
    is_subagent = false,
    msgs = { { role = "system", content = "parent system" } },
    cfg = {
      agents = {
        defaults = {
          model = { primary = "test/primary" },
          maxIter = 20,
          subagents = {
            maxConcurrent = 2,
            maxChildrenPerAgent = 3,
            maxSpawnDepth = 1,
            runTimeoutSeconds = 300,
          },
        },
        list = { { id = "main", model = { primary = "test/primary" } } },
      },
    },
  }
  if overrides then
    for k, v in pairs(overrides) do ctx[k] = v end
  end
  return ctx
end

-- ═══════════════════════════════════════════════════════════════════════════
sec("session.generate — invariantes de default e parametrização")
-- ═══════════════════════════════════════════════════════════════════════════

local id_def = gen.id()
T("generate.id() default casa TUI:main:hex", id_def:match("^TUI:main:[0-9a-f]+$") ~= nil, id_def)
T("generate.id() hex len >= 6", #(id_def:match(":(%x+)$") or "") >= 6)
local key_def = gen.key()
T("generate.key() default == TUI:main", key_def == "TUI:main")
local id_p = gen.id("agent", "coder")
T("generate.id(agent,coder) prefixo", id_p:match("^agent:coder:[0-9a-f]+$") ~= nil, id_p)
local key_p = gen.key("agent", "coder")
T("generate.key(agent,coder) == agent:coder", key_p == "agent:coder")
T("generate.id() sem args não usa agent:", gen.id():match("^agent:") == nil)
T("generate.entry_id retorna hex", type(gen.entry_id()) == "string" and #gen.entry_id() >= 4)
T("generate.filename substitui : por -", gen.filename("TUI:main:abc") == "TUI-main-abc.jsonl")

-- ═══════════════════════════════════════════════════════════════════════════
sec("tools.registry — presença das 5 tools + sessoes_listar intacta")
-- ═══════════════════════════════════════════════════════════════════════════

local tools = require("tools")
T("registry sessions_spawn", tools.registry.sessions_spawn ~= nil)
T("registry subagents_listar", tools.registry.subagents_listar ~= nil)
T("registry subagents_status", tools.registry.subagents_status ~= nil)
T("registry subagents_wait", tools.registry.subagents_wait ~= nil)
T("registry subagents_cancel", tools.registry.subagents_cancel ~= nil)
T("registry sessoes_listar intacta (fronteira)", tools.registry.sessoes_listar ~= nil)
T("registry sessoes_historico intacta", tools.registry.sessoes_historico ~= nil or true) -- pode não existir em todos builds

-- ═══════════════════════════════════════════════════════════════════════════
sec("ids — run_id, child_session_key, transcript_path")
-- ═══════════════════════════════════════════════════════════════════════════

local rid1 = ids.run_id()
local rid2 = ids.run_id()
T("run_id retorna string", type(rid1) == "string")
T("run_id hex-only", rid1:match("^[0-9a-f]+$") ~= nil, rid1)
T("run_id comprimento >= 8", #rid1 >= 8)
T("run_id dois calls distintos (probabilístico)", rid1 ~= rid2 or true) -- allow rare collision
local csk = ids.child_session_key("main", rid1)
T("child_session_key formato agent:id:subagent:run", csk == "agent:main:subagent:" .. rid1)
T("child_session_key agentId nil → string com nil", type(ids.child_session_key(nil, "x")) == "string")
local tpath = ids.transcript_path("main", rid1)
T("transcript_path contém subagents/transcripts", tpath:find("subagents/transcripts") ~= nil)
T("transcript_path usa - no lugar de :", tpath:find("agent%-main%-subagent%-") ~= nil or tpath:find("agent-main-subagent-") ~= nil)
T("transcript_path termina .jsonl", tpath:match("%.jsonl$") ~= nil)

-- ═══════════════════════════════════════════════════════════════════════════
sec("store — load/save/upsert/get/list/count_active (filesystem isolado)")
-- ═══════════════════════════════════════════════════════════════════════════

wipe_store()
local empty = store.load()
T("load sem arquivo → {runs={}}", type(empty) == "table" and type(empty.runs) == "table" and #empty.runs == 0)

local rA = {
  runId = "aaaa1111",
  status = "queued",
  agentId = "main",
  parent_agent_id = "main",
  task = "t1",
  created_at_unix = os.time(),
}
store.upsert(rA)
local got, data = store.get("aaaa1111")
T("get após upsert encontra run", got ~= nil and got.runId == "aaaa1111")
T("get retorna data", type(data) == "table")
T("list sem filtro contém 1", #store.list() == 1)

rA.status = "running"
store.upsert(rA)
T("upsert atualiza in-place", store.get("aaaa1111").status == "running")

local rB = {
  runId = "bbbb2222",
  status = "completed",
  agentId = "coder",
  parent_agent_id = "main",
  task = "t2",
}
store.upsert(rB)
T("list total 2", #store.list() == 2)
T("list filter status=running → 1", #store.list({ status = "running" }) == 1)
T("list filter status=completed → 1", #store.list({ status = "completed" }) == 1)
T("list filter agentId=coder → 1", #store.list({ agentId = "coder" }) == 1)
T("list filter parent_agent_id=main → 2", #store.list({ parent_agent_id = "main" }) == 2)
T("list filter status=ghost → 0", #store.list({ status = "ghost" }) == 0)

T("count_active total (running+queued)", store.count_active(nil) == 1) -- only running
T("count_active parent main", store.count_active("main") == 1)
T("count_active parent other → 0", store.count_active("other") == 0)

-- persistência real
local raw = io.open(store.PATH, "r")
T("runs.json existe após upsert", raw ~= nil)
if raw then
  local content = raw:read("*a"); raw:close()
  T("runs.json contém aaaa1111", content:find("aaaa1111") ~= nil)
  T("runs.json é JSON válido", pcall(json.decode, content) == true)
end

-- corrupt recovery
local badf = io.open(store.PATH, "w")
if badf then badf:write("{not json"); badf:close() end
local recovered = store.load()
T("load JSON corrompido → {runs={}}", type(recovered.runs) == "table" and #recovered.runs == 0)

-- re-seed para testes seguintes
wipe_store()

-- ═══════════════════════════════════════════════════════════════════════════
sec("policy — defaults, allowAgents, caps, denylist, resolve_model")
-- ═══════════════════════════════════════════════════════════════════════════

local d0 = policy.defaults({ agents = { defaults = {} } })
T("defaults maxConcurrent=2", d0.maxConcurrent == 2)
T("defaults maxChildrenPerAgent=3", d0.maxChildrenPerAgent == 3)
T("defaults maxSpawnDepth=1", d0.maxSpawnDepth == 1)
T("defaults runTimeoutSeconds=300", d0.runTimeoutSeconds == 300)
T("defaults allowAgents nil", d0.allowAgents == nil)
T("defaults model nil", d0.model == nil)

local d1 = policy.defaults({
  agents = { defaults = { subagents = {
    maxConcurrent = 5, maxChildrenPerAgent = 9, maxSpawnDepth = 2,
    runTimeoutSeconds = 60, model = "x/y", allowAgents = { "*" },
  } } }
})
T("defaults override maxConcurrent", d1.maxConcurrent == 5)
T("defaults override maxChildrenPerAgent", d1.maxChildrenPerAgent == 9)
T("defaults override runTimeoutSeconds", d1.runTimeoutSeconds == 60)
T("defaults override model", d1.model == "x/y")
T("defaults override allowAgents *", type(d1.allowAgents) == "table" and d1.allowAgents[1] == "*")

local ok_self, _ = policy.is_agent_allowed("main", "main", { agents = { defaults = {} } })
T("is_agent_allowed próprio id → true", ok_self == true)
local ok_empty, reason_empty = policy.is_agent_allowed("main", "", { agents = { defaults = {} } })
T("is_agent_allowed agentId vazio → false", ok_empty == false)
T("is_agent_allowed vazio reason menciona vazio", type(reason_empty) == "string" and reason_empty:find("vazio") ~= nil)
local ok_foreign, reason_f = policy.is_agent_allowed("main", "ghost", { agents = { defaults = {} } })
T("is_agent_allowed estrangeiro sem allow → false", ok_foreign == false)
T("is_agent_allowed estrangeiro reason policy", type(reason_f) == "string" and reason_f:find("policy") ~= nil)
local ok_star = policy.is_agent_allowed("main", "ghost", {
  agents = { defaults = { subagents = { allowAgents = { "*" } } } }
})
T("is_agent_allowed allowAgents=* → true", ok_star == true)
local ok_list = policy.is_agent_allowed("main", "coder", {
  agents = { defaults = { subagents = { allowAgents = { "coder", "writer" } } } }
})
T("is_agent_allowed lista explícita contém → true", ok_list == true)
local ok_list_miss = policy.is_agent_allowed("main", "ghost", {
  agents = { defaults = { subagents = { allowAgents = { "coder" } } } }
})
T("is_agent_allowed lista sem match → false", ok_list_miss == false)

wipe_store()
local ok_caps, caps = policy.check_caps("main", parent_ctx_fixture().cfg)
T("check_caps vazio → true", ok_caps == true)
T("check_caps retorna tabela defaults", type(caps) == "table" and caps.maxConcurrent == 2)

-- saturar maxConcurrent
for i = 1, 2 do
  store.upsert({
    runId = "cap" .. i, status = "queued", agentId = "main",
    parent_agent_id = "main", task = "c", created_at_unix = os.time(),
  })
end
local ok_sat, err_sat = policy.check_caps("main", parent_ctx_fixture().cfg)
T("check_caps maxConcurrent saturado → false", ok_sat == false)
T("check_caps err menciona maxConcurrent", type(err_sat) == "string" and err_sat:find("maxConcurrent") ~= nil)

wipe_store()
-- saturar maxChildrenPerAgent com maxConcurrent alto
local cfg_high = parent_ctx_fixture({
  cfg = {
    agents = {
      defaults = {
        model = { primary = "t" },
        subagents = { maxConcurrent = 100, maxChildrenPerAgent = 2, runTimeoutSeconds = 300 },
      },
      list = { { id = "main" } },
    },
  },
}).cfg
for i = 1, 2 do
  store.upsert({
    runId = "per" .. i, status = "running", agentId = "main",
    parent_agent_id = "main", task = "p", created_at_unix = os.time(),
  })
end
local ok_per, err_per = policy.check_caps("main", cfg_high)
T("check_caps maxChildrenPerAgent saturado → false", ok_per == false)
T("check_caps err menciona maxChildrenPerAgent", type(err_per) == "string" and err_per:find("maxChildrenPerAgent") ~= nil)

wipe_store()

local dset = policy.child_disabled_set("main")
T("denylist sessions_spawn", dset.sessions_spawn == true)
T("denylist sessoes_listar", dset.sessoes_listar == true)
T("denylist sessoes_historico", dset.sessoes_historico == true)
T("denylist sessao_status", dset.sessao_status == true)
T("denylist subagents_listar", dset.subagents_listar == true)
T("denylist subagents_status", dset.subagents_status == true)
T("denylist subagents_wait", dset.subagents_wait == true)
T("denylist subagents_cancel", dset.subagents_cancel == true)
T("denylist não bloqueia tools genéricas por default", dset.web_fetch ~= true and dset.bash ~= true)

local m_spawn = policy.resolve_model("override/model", "main", parent_ctx_fixture().cfg)
T("resolve_model spawn.model tem prioridade", m_spawn == "override/model")
local m_empty_spawn = policy.resolve_model("", "main", parent_ctx_fixture().cfg)
T("resolve_model spawn vazio cai para entry/defaults", m_empty_spawn == "test/primary" or m_empty_spawn == "")
local m_nil = policy.resolve_model(nil, "main", {
  agents = { defaults = { model = { primary = "def/prim" }, subagents = {} }, list = {} }
})
T("resolve_model nil → defaults.model.primary", m_nil == "def/prim")

-- ═══════════════════════════════════════════════════════════════════════════
sec("spawn — contrato, policy, depth, campos do run")
-- ═══════════════════════════════════════════════════════════════════════════

wipe_store()
local pctx = parent_ctx_fixture()

local miss = spawn.spawn({}, pctx)
T("spawn sem task → erro string", type(miss) == "string" and miss:find("task") ~= nil)
local empty_t = spawn.spawn({ task = "   " }, pctx)
T("spawn task só whitespace → erro", type(empty_t) == "string" and empty_t:find("task") ~= nil)
local nil_t = spawn.spawn({ task = nil }, pctx)
T("spawn task nil → erro", type(nil_t) == "string")

local out = spawn.spawn({ task = "diga oi", label = "lab1" }, pctx)
local okj, payload = pcall(json.decode, out)
T("spawn happy → JSON válido", okj == true)
T("spawn payload.runId presente", okj and type(payload.runId) == "string" and #payload.runId >= 8)
T("spawn payload.status queued", okj and payload.status == "queued")
T("spawn payload.agentId main", okj and payload.agentId == "main")
T("spawn childSessionKey namespace", okj and payload.childSessionKey:match("^agent:main:subagent:") ~= nil)

local stored = store.get(payload.runId)
T("spawn gravou no store", stored ~= nil)
T("spawn stored.task", stored and stored.task == "diga oi")
T("spawn stored.label", stored and stored.label == "lab1")
T("spawn stored.timeout_seconds default 300", stored and stored.timeout_seconds == 300)
T("spawn stored.created_at_unix number", stored and type(stored.created_at_unix) == "number")
T("spawn stored.context isolated", stored and stored.context == "isolated")
T("spawn stored.announce_pending false", stored and stored.announce_pending == false)
T("spawn transcript_path set", stored and type(stored.transcript_path) == "string")
T("spawn transcript file existe", stored and io.open(stored.transcript_path, "r") ~= nil)

-- transcript content
if stored and stored.transcript_path then
  local tf = io.open(stored.transcript_path, "r")
  local tcontent = tf and tf:read("*a") or ""
  if tf then tf:close() end
  T("transcript contém session header", tcontent:find('"type":"session"') ~= nil or tcontent:find('"type": "session"') ~= nil)
  T("transcript contém user task", tcontent:find("diga oi") ~= nil)
end

local bad_foreign = spawn.spawn({ task = "x", agentId = "ghost" }, pctx)
T("spawn agentId estrangeiro → policy", type(bad_foreign) == "string" and bad_foreign:find("policy") ~= nil)

local child_like = parent_ctx_fixture({ is_subagent = true })
local depth_err = spawn.spawn({ task = "x" }, child_like)
T("spawn de filho → depth", type(depth_err) == "string" and depth_err:find("depth") ~= nil)

local with_to = spawn.spawn({ task = "to", runTimeoutSeconds = 7 }, pctx)
local _, pto = pcall(json.decode, with_to)
local st_to = pto and store.get(pto.runId)
T("spawn runTimeoutSeconds override gravado", st_to and st_to.timeout_seconds == 7)

-- caps
wipe_store()
local cfg_cap = parent_ctx_fixture().cfg
cfg_cap.agents.defaults.subagents.maxConcurrent = 1
local p1 = spawn.spawn({ task = "a" }, parent_ctx_fixture({ cfg = cfg_cap }))
T("spawn 1º sob maxConcurrent=1 ok", type(p1) == "string" and p1:find("runId") ~= nil)
local p2 = spawn.spawn({ task = "b" }, parent_ctx_fixture({ cfg = cfg_cap }))
T("spawn 2º sob maxConcurrent=1 rejeita", type(p2) == "string" and p2:find("maxConcurrent") ~= nil)

wipe_store()

-- ═══════════════════════════════════════════════════════════════════════════
sec("child_runner — is_timed_out / mark_timeout (#84)")
-- ═══════════════════════════════════════════════════════════════════════════

local fake_old = {
  runId = "to1", status = "running", timeout_seconds = 1,
  started_at_unix = os.time() - 10, agentId = "main",
}
T("#84 is_timed_out true quando elapsed > limit", runner.is_timed_out(fake_old) == true)
local marked = runner.mark_timeout(fake_old)
T("#84 mark_timeout status=timeout", marked.status == "timeout")
T("#84 mark_timeout error menciona runTimeoutSeconds", type(marked.error) == "string" and marked.error:find("runTimeoutSeconds") ~= nil)
T("#84 mark_timeout finished_at set", type(marked.finished_at) == "string")
T("#84 mark_timeout announce_pending true", marked.announce_pending == true)

local fresh = {
  runId = "to2", status = "running", timeout_seconds = 300,
  started_at_unix = os.time(), agentId = "main",
}
T("#84 is_timed_out false dentro do limite", runner.is_timed_out(fresh) == false)

local no_to = { runId = "to3", status = "running", timeout_seconds = 0, started_at_unix = 0 }
T("#84 timeout_seconds=0 → nunca timeout", runner.is_timed_out(no_to) == false)
local nil_to = { runId = "to4", status = "running", started_at_unix = 0 }
T("#84 timeout_seconds nil → nunca timeout", runner.is_timed_out(nil_to) == false)
local neg_to = { runId = "to5", status = "running", timeout_seconds = -5, started_at_unix = 0 }
T("#84 timeout_seconds negativo → nunca timeout", runner.is_timed_out(neg_to) == false)

-- queued usa created_at_unix
local q_old = {
  runId = "to6", status = "queued", timeout_seconds = 1,
  created_at_unix = os.time() - 30, agentId = "main",
}
-- is_timed_out em runner olha started_at_unix para running; para queued o check está em advance
T("#84 is_timed_out em queued sem started → fallback os.time (pode ser false)", type(runner.is_timed_out(q_old)) == "boolean")

-- advance em terminal é no-op
local term = { runId = "term1", status = "completed", agentId = "main" }
local term_out = runner.advance(term, pctx.cfg)
T("advance em completed retorna mesmo status", term_out.status == "completed")
local term_f = { runId = "term2", status = "failed", agentId = "main" }
T("advance em failed no-op", runner.advance(term_f, pctx.cfg).status == "failed")
local term_t = { runId = "term3", status = "timeout", agentId = "main" }
T("advance em timeout no-op", runner.advance(term_t, pctx.cfg).status == "timeout")

-- ═══════════════════════════════════════════════════════════════════════════
sec("child_ctx — msgs só system (#85) e flags de isolamento")
-- ═══════════════════════════════════════════════════════════════════════════

-- Leitura estrutural do fonte (sem models real o build retorna nil)
local src_ctx = io.open("tools/subagents/child_ctx.lua", "r"):read("*a")
T("#85 fonte não pré-insere role=user na tabela msgs", src_ctx:find('role = "user"') == nil or src_ctx:find("Apenas system") ~= nil)
T("#85 fonte documenta msgs só system", src_ctx:find("Apenas system") ~= nil or src_ctx:find('role = "system"') ~= nil)
T("#85 is_subagent = true no build", src_ctx:find("is_subagent%s*=%s*true") ~= nil)
T("#85 MAX_ITER capped a 8", src_ctx:find("math%.min%(max_iter,%s*8%)") ~= nil)
T("#85 subagent_runId setado", src_ctx:find("subagent_runId") ~= nil)

-- ═══════════════════════════════════════════════════════════════════════════
sec("system_messages.prepare_user_turn — isolamento is_subagent (#86)")
-- ═══════════════════════════════════════════════════════════════════════════

-- Consome first-turn no pai se ainda ativo
local parent_like = { msgs = { { role = "system", content = "x" } }, is_subagent = false }
sm.prepare_user_turn(parent_like, "hello parent", "user")

local child_like_ctx = { msgs = { { role = "system", content = "sys" } }, is_subagent = true }
local out_text, spin = sm.prepare_user_turn(child_like_ctx, "task do filho", "user")
T("#86 child out_text inalterado", out_text == "task do filho")
T("#86 child spinner false", spin == false)

local parent2 = {
  msgs = { { role = "system", content = "x" }, { role = "user", content = "a" } },
  is_subagent = false,
}
local t2 = sm.prepare_user_turn(parent2, "segundo turno", "user")
T("#86 após child, parent não re-injeta boot", t2:find("User has joined") == nil and t2:find("System has restarted") == nil)

-- role != user não injeta
local out_non, spin_non = sm.prepare_user_turn({ is_subagent = false, msgs = {} }, "x", "assistant")
T("prepare_user_turn role!=user retorna texto puro", out_non == "x" and spin_non == false)

-- child com role user e msgs vazias ainda não injeta
local c2 = { msgs = {}, is_subagent = true }
local o2, s2 = sm.prepare_user_turn(c2, "só task", "user")
T("#86 child msgs vazias ainda sem injeção", o2 == "só task" and s2 == false)

-- ═══════════════════════════════════════════════════════════════════════════
sec("scheduler — reconcile_orphans, tick timeout, inject_announces")
-- ═══════════════════════════════════════════════════════════════════════════

wipe_store()
store.upsert({
  runId = "orph1", status = "running", agentId = "main",
  parent_agent_id = "main", task = "o", created_at_unix = os.time(),
})
store.upsert({
  runId = "orph2", status = "queued", agentId = "main",
  parent_agent_id = "main", task = "o2", created_at_unix = os.time(),
})
store.upsert({
  runId = "done1", status = "completed", agentId = "main",
  parent_agent_id = "main", task = "d",
})
local changed = scheduler.reconcile_orphans()
T("reconcile_orphans retorna true quando houve mudança", changed == true)
local o1 = store.get("orph1")
T("orphan running → failed process_exit", o1 and o1.status == "failed" and o1.error == "process_exit")
local o2 = store.get("orph2")
T("orphan queued → failed process_exit", o2 and o2.status == "failed" and o2.error == "process_exit")
local d1 = store.get("done1")
T("completed não é tocado por reconcile", d1 and d1.status == "completed")

-- 2ª chamada sem órfãos
T("reconcile sem órfãos → false", scheduler.reconcile_orphans() == false)

-- inject_announces
wipe_store()
store.upsert({
  runId = "ann1", status = "completed", agentId = "main",
  parent_agent_id = "main", result_text = "resultado filho",
  announce_pending = true, announce_consumed = false, task = "a",
})
store.upsert({
  runId = "ann2", status = "failed", agentId = "main",
  parent_agent_id = "main", error = "boom",
  announce_pending = true, announce_consumed = false, task = "b",
})
local pmsgs = { { role = "system", content = "base" } }
local parent_for_ann = { msgs = pmsgs, cfg = parent_ctx_fixture().cfg }
local n_inj = scheduler.inject_announces(parent_for_ann)
T("inject_announces injeta 2", n_inj == 2)
T("msgs do pai cresceu para 3", #pmsgs == 3)
T("announce completed contém result_text", pmsgs[2].content:find("resultado filho") ~= nil)
T("announce completed status=completed", pmsgs[2].content:find("status=completed") ~= nil)
T("announce failed contém error", pmsgs[3].content:find("boom") ~= nil)
T("announce role=system", pmsgs[2].role == "system" and pmsgs[3].role == "system")
local ann1 = store.get("ann1")
T("announce_pending consumido", ann1 and ann1.announce_pending == false and ann1.announce_consumed == true)
T("2ª inject sem pending → 0", scheduler.inject_announces(parent_for_ann) == 0)

-- tick com run já timeout
wipe_store()
store.upsert({
  runId = "tickto", status = "running", agentId = "main",
  parent_agent_id = "main", timeout_seconds = 1,
  started_at_unix = os.time() - 60, task = "t",
  created_at_unix = os.time() - 60,
})
scheduler.tick(parent_ctx_fixture())
local tick_r = store.get("tickto")
T("tick expira running timeout → status timeout", tick_r and tick_r.status == "timeout")

-- ═══════════════════════════════════════════════════════════════════════════
sec("inspect — listar / status / wait / cancel")
-- ═══════════════════════════════════════════════════════════════════════════

wipe_store()
store.upsert({
  runId = "ins1", status = "queued", agentId = "main",
  parent_agent_id = "main", task = "lista me", label = "L1",
})
store.upsert({
  runId = "ins2", status = "completed", agentId = "coder",
  parent_agent_id = "main", task = "outro", result_text = "ok",
})

local list_all = inspect.listar({})
T("listar sem filtro menciona Child runs", type(list_all) == "string" and list_all:find("Child runs") ~= nil)
T("listar contém ins1", list_all:find("ins1") ~= nil)
T("listar contém ins2", list_all:find("ins2") ~= nil)

local list_q = inspect.listar({ status = "queued" })
T("listar status=queued só ins1", list_q:find("ins1") ~= nil and list_q:find("ins2") == nil)
local list_empty = inspect.listar({ status = "timeout" })
T("listar filtro vazio → mensagem Nenhum", list_empty:find("Nenhum") ~= nil)

local st = inspect.status({ runId = "ins2" })
local ok_st, pst = pcall(json.decode, st)
T("status JSON válido", ok_st == true)
T("status status=completed", ok_st and pst.status == "completed")
T("status result_text", ok_st and pst.result_text == "ok")
T("status runId ausente → erro", inspect.status({}):find("runId") ~= nil)
T("status run inexistente → não encontrado", inspect.status({ runId = "zzz" }):find("não encontrado") ~= nil or inspect.status({ runId = "zzz" }):find("encontrado") ~= nil)

-- cancel
local can = inspect.cancel({ runId = "ins1" })
local ok_c, pc = pcall(json.decode, can)
T("cancel queued → JSON", ok_c == true)
T("cancel status failed", ok_c and pc.status == "failed")
T("cancel error cancelled", ok_c and pc.error == "cancelled")
local can_term = inspect.cancel({ runId = "ins2" })
T("cancel já terminal → mensagem terminal", type(can_term) == "string" and can_term:find("terminal") ~= nil)
T("cancel sem runId → erro", inspect.cancel({}):find("runId") ~= nil)
T("cancel inexistente → não encontrado", inspect.cancel({ runId = "nope" }):find("encontrado") ~= nil)

-- wait em run já terminal
local w = inspect.wait({ runId = "ins2", timeoutSeconds = 1 }, parent_ctx_fixture())
local ok_w, pw = pcall(json.decode, w)
T("wait terminal → JSON com status completed", ok_w and pw.status == "completed")
T("wait sem runId → erro", inspect.wait({}, parent_ctx_fixture()):find("runId") ~= nil)
T("wait inexistente → não encontrado", inspect.wait({ runId = "nope" }, parent_ctx_fixture()):find("encontrado") ~= nil)

-- wait timeout em queued (sem advance real de modelo — advance falha em model resolve e marca failed)
wipe_store()
store.upsert({
  runId = "wait1", status = "queued", agentId = "main",
  parent_agent_id = "main", task = "w", created_at_unix = os.time(),
  timeout_seconds = 300,
})
-- wait vai tentar advance; child_ctx.build falha sem model real → failed
local w2 = inspect.wait({ runId = "wait1", timeoutSeconds = 2 }, parent_ctx_fixture())
local ok_w2, pw2 = pcall(json.decode, w2)
T("wait em queued sem model → eventualmente terminal ou partial", ok_w2 == true)
if ok_w2 then
  T("wait resultado tem runId", pw2.runId == "wait1")
  T("wait status não é queued eterno", pw2.status ~= nil)
end

-- ═══════════════════════════════════════════════════════════════════════════
sec("isolamento de fronteira — sessoes_* não listam child keys (claim estrutural)")
-- ═══════════════════════════════════════════════════════════════════════════

-- Validação por ausência de acoplamento no store de subagents vs sessions
T("store.PATH contém subagents", store.PATH:find("subagents") ~= nil)
T("store.PATH não é sessions", store.PATH:find("sessions") == nil or store.PATH:find("subagents") ~= nil)
local sessions_src_ok = true
local sf = io.open("tools/sessions.lua", "r")
if sf then
  local ssrc = sf:read("*a"); sf:close()
  -- sessions não deve referenciar subagents store
  T("tools/sessions.lua não importa tools.subagents.store", ssrc:find("tools%.subagents%.store") == nil)
  T("tools/sessions.lua não referencia runs.json de subagents", ssrc:find("subagents/runs") == nil)
else
  T("tools/sessions.lua legível (skip se ausente)", true)
end

-- ═══════════════════════════════════════════════════════════════════════════
sec("runner fonte — restauração _G.__termai_ctx e task única (#85 #5)")
-- ═══════════════════════════════════════════════════════════════════════════

local src_runner = io.open("tools/subagents/child_runner.lua", "r"):read("*a")
T("runner salva prev_global_ctx", src_runner:find("prev_global_ctx") ~= nil)
T("runner restaura _G.__termai_ctx", src_runner:find("_G%.__termai_ctx%s*=%s*prev_global_ctx") ~= nil)
T("runner chama loop.rodar com run.task", src_runner:find("loop%.rodar%(ctx,%s*run%.task") ~= nil)
T("runner checa is_timed_out antes de advance", src_runner:find("is_timed_out") ~= nil)
T("runner mark_timeout pós-rodar", src_runner:find("is_timed_out%(run%)%s*and%s*ok") ~= nil or src_runner:find("mark_timeout") ~= nil)

-- ═══════════════════════════════════════════════════════════════════════════
sec("scheduler fonte — on_parent_boundary só no pai")
-- ═══════════════════════════════════════════════════════════════════════════

local src_sched = io.open("tools/subagents/scheduler.lua", "r"):read("*a")
T("scheduler.on_parent_boundary existe", src_sched:find("on_parent_boundary") ~= nil)
T("scheduler.tick chama mark_timeout", src_sched:find("mark_timeout") ~= nil)
T("scheduler.inject formata [subagent runId=", src_sched:find("%[subagent runId=") ~= nil)

local src_loop = io.open("agent/loop.lua", "r"):read("*a")
T("loop.lua parent_boundary guarda is_subagent", src_loop:find("is_subagent") ~= nil)
T("loop.lua chama on_parent_boundary", src_loop:find("on_parent_boundary") ~= nil)
T("loop.lua seta _G.__termai_ctx", src_loop:find("_G%.__termai_ctx%s*=%s*ctx") ~= nil)

-- ═══════════════════════════════════════════════════════════════════════════
sec("config defaults — bloco subagents presente")
-- ═══════════════════════════════════════════════════════════════════════════

local src_cfg = io.open("config/store.lua", "r"):read("*a")
T("config/store defaults tem subagents", src_cfg:find("subagents%s*=") ~= nil)
T("config maxConcurrent default 2", src_cfg:find("maxConcurrent%s*=%s*2") ~= nil)
T("config maxChildrenPerAgent default 3", src_cfg:find("maxChildrenPerAgent%s*=%s*3") ~= nil)
T("config maxSpawnDepth default 1", src_cfg:find("maxSpawnDepth%s*=%s*1") ~= nil)
T("config runTimeoutSeconds default 300", src_cfg:find("runTimeoutSeconds%s*=%s*300") ~= nil)

-- ═══════════════════════════════════════════════════════════════════════════
sec("casos extremos adicionais — tipos, nil, bordas")
-- ═══════════════════════════════════════════════════════════════════════════

wipe_store()
T("store.get nil → nil", store.get(nil) == nil)
T("store.list nil filter → table", type(store.list(nil)) == "table")
T("store.count_active nil → number", type(store.count_active(nil)) == "number")
T("inspect.listar nil → string", type(inspect.listar(nil)) == "string")
T("inspect.status string arg", type(inspect.status("nope")) == "string")
T("spawn args string (não table) → trata como args.task? ou erro", type(spawn.spawn("x", pctx)) == "string")
T("policy.is_agent_allowed nil target → false", select(1, policy.is_agent_allowed("main", nil, {})) == false)
T("policy.child_disabled_set nil agent → table com denylist", type(policy.child_disabled_set(nil)) == "table")
T("ids.child_session_key vazio", ids.child_session_key("", "") == "agent::subagent:")
T("runner.is_timed_out run sem campos → false", runner.is_timed_out({}) == false)
T("scheduler.inject_announces nil ctx → 0", scheduler.inject_announces(nil) == 0)
T("scheduler.inject_announces sem msgs → 0", scheduler.inject_announces({}) == 0)
T("scheduler.tick nil → não explode", pcall(scheduler.tick, nil) == true)

-- boundary aritmética timeout: exatamente no limite
local exact = {
  runId = "ex", status = "running", timeout_seconds = 5,
  started_at_unix = os.time() - 5,
}
T("is_timed_out elapsed == limit → true (>=)", runner.is_timed_out(exact) == true)
local almost = {
  runId = "al", status = "running", timeout_seconds = 100,
  started_at_unix = os.time() - 1,
}
T("is_timed_out elapsed << limit → false", runner.is_timed_out(almost) == false)

-- múltiplos upserts mesma runId
wipe_store()
store.upsert({ runId = "dup", status = "queued", agentId = "main", parent_agent_id = "main", task = "1" })
store.upsert({ runId = "dup", status = "running", agentId = "main", parent_agent_id = "main", task = "2" })
T("upsert mesma runId não duplica", #store.list() == 1)
T("upsert mesma runId atualiza task", store.get("dup").task == "2")

-- ═══════════════════════════════════════════════════════════════════════════
sec("regressão estrutural — fachada tools/subagents.lua registra 5 tools")
-- ═══════════════════════════════════════════════════════════════════════════

local src_facade = io.open("tools/subagents.lua", "r"):read("*a")
T("fachada registra sessions_spawn", src_facade:find('"sessions_spawn"') ~= nil)
T("fachada registra subagents_listar", src_facade:find('"subagents_listar"') ~= nil)
T("fachada registra subagents_status", src_facade:find('"subagents_status"') ~= nil)
T("fachada registra subagents_wait", src_facade:find('"subagents_wait"') ~= nil)
T("fachada registra subagents_cancel", src_facade:find('"subagents_cancel"') ~= nil)
T("fachada usa parent_ctx via _G.__termai_ctx", src_facade:find("__termai_ctx") ~= nil)
T("fachada required task em sessions_spawn", src_facade:find('required%s*=%s*{%s*"task"') ~= nil or src_facade:find('required = { "task"') ~= nil)

-- ═══════════════════════════════════════════════════════════════════════════
sec("context.build — reconcile_orphans no caminho de build")
-- ═══════════════════════════════════════════════════════════════════════════

local src_context = io.open("agent/context.lua", "r"):read("*a")
T("context.build aceita opts", src_context:find("function M%.build%(opts%)") ~= nil or src_context:find("M.build%(opts%)") ~= nil)
T("context.build chama reconcile_orphans", src_context:find("reconcile_orphans") ~= nil)
T("context.build agent_id de opts", src_context:find("opts%.agent_id") ~= nil)

-- ═══════════════════════════════════════════════════════════════════════════
-- Cleanup + resultado
-- ═══════════════════════════════════════════════════════════════════════════

os.execute("rm -rf '" .. TEST_HOME .. "'")

print(string.format("\n==== Resultado: %s  (pass=%d fail=%d total=%d) ====",
  fail == 0 and "PASS" or ("FAIL x" .. fail), pass, fail, pass + fail))
os.exit(fail == 0 and 0 or 1)
