package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local models = require("models")
local store = require("models.store")
local validate = require("models.validate")
local shared = require("commands.config.fallback_keys")
local pass, fail = 0, 0
local function T(name, ok)
  if ok then pass = pass + 1; print("  PASS " .. name)
  else fail = fail + 1; print("  FAIL " .. name) end
end

local dir = "/tmp/termai_fallback_keys_spec"
store.PATH = dir .. "/models.json"
os.execute("mkdir -p " .. dir)
os.remove(store.PATH)
store._data = nil
models.load()

models.add_provider({
  id = "fallback-spec", baseUrl = "https://example.invalid/v1",
  api = "openai-completions",
  apiKeys = { "key-one", "key-two", "key-three" },
  models = {{ id = "model", name = "Fallback Spec" }},
})
models.set_active("fallback-spec/model")
models.set_active_api_key("fallback-spec", 3)

local calls = {}
local original_test = validate.test_connection
validate.test_connection = function(active, options)
  calls[#calls + 1] = { key = active.api_key, options = options }
  return active.api_key == "key-two", active.api_key == "key-two" and "OK" or "invalid key"
end

-- A) Teste unitário de uma chave
local ok_one = models.test_api_key("fallback-spec", "fallback-spec/model", 1)
local _, active_index = models.active_api_key("fallback-spec")
T("individual key test does not change active key", ok_one == false and active_index == 3)

local keys_after = models.list_api_keys("fallback-spec")
T("individual failure records health only on tested index",
  keys_after[1].last_error_at ~= nil
  and keys_after[2].last_error_at == nil
  and keys_after[3].last_error_at == nil)

local results, invalid = shared.test_all("fallback-spec")
_, active_index = models.active_api_key("fallback-spec")
T("test-all returns every result and failed indices",
  results and #results == 3 and #invalid == 2)
T("test-all preserves the active key", active_index == 3)
T("key tests use bounded connection timeouts",
  calls[1].options.connect_timeout == 2 and calls[1].options.max_time == 6)

-- B) Ciclo de topo no boot (Issue #370):
-- ativa em 3; key1 ruim, key2 OK → recupera para 2 (mais próxima do topo saudável)
local before_boot = #calls
local recovered, recovered_index = models.prefer_top_api_key_on_boot("fallback-spec/model", {
  connect_timeout = 1, max_time = 3,
})
local active_key
active_key, active_index = models.active_api_key("fallback-spec")
T("boot recovers nearest healthy top when previous keys include a good one",
  recovered and recovered_index == 2 and active_index == 2 and active_key == "key-two"
  and #calls == before_boot + 2)

-- ativa em 2; key1 OK → deve subir para o topo mesmo com preferida atual saudável
validate.test_connection = function(active, options)
  calls[#calls + 1] = { key = active.api_key, options = options }
  return active.api_key == "key-one", "OK"
end
models.set_active_api_key("fallback-spec", 2)
local before_prefer_top = #calls
local moved_to_top, top_index = models.prefer_top_api_key_on_boot("fallback-spec/model", {
  connect_timeout = 1, max_time = 3,
})
active_key, active_index = models.active_api_key("fallback-spec")
T("boot prefers top even when current preferred key is still healthy",
  moved_to_top and top_index == 1 and active_index == 1 and active_key == "key-one"
  and #calls == before_prefer_top + 1)

-- Já no topo: zero probes (nada anterior para recuperar)
validate.test_connection = function(active, options)
  calls[#calls + 1] = { key = active.api_key, options = options }
  return true, "OK"
end
local before_top = #calls
local moved = models.prefer_top_api_key_on_boot("fallback-spec/model", {
  connect_timeout = 1, max_time = 3,
})
_, active_index = models.active_api_key("fallback-spec")
T("boot at top index does not probe",
  not moved and active_index == 1 and #calls == before_top)

-- Ativa em 3; todas as anteriores ruins → mantém 3 e só testa 1..2 (não re-testa a atual)
models.set_active_api_key("fallback-spec", 3)
validate.test_connection = function(active, options)
  calls[#calls + 1] = { key = active.api_key, options = options }
  return false, "down"
end
local before_all_fail = #calls
local recovered_none = models.prefer_top_api_key_on_boot("fallback-spec/model", {
  connect_timeout = 1, max_time = 3,
})
_, active_index = models.active_api_key("fallback-spec")
T("boot keeps current key when all previous keys fail",
  not recovered_none and active_index == 3 and #calls == before_all_fail + 2)

-- F) Dashboard
validate.test_connection = function(active, options)
  calls[#calls + 1] = { key = active.api_key, options = options }
  return active.api_key == "key-two", "OK"
end
models.set_active_api_key("fallback-spec", 2)
models.test_api_key("fallback-spec", "fallback-spec/model", 2)
local rows = shared.dashboard("fallback-spec")
T("dashboard exposes health and active state",
  #rows == 3 and rows[2].state == "OK" and rows[2].active)
T("dashboard key masks stay compact on narrow terminals", #rows[2].masked <= 12)

-- Provedor sem chaves: zero probes
models.add_provider({
  id = "no-key-spec", baseUrl = "https://example.invalid/v1",
  api = "openai-completions", apiKeys = {},
  models = {{ id = "model", name = "No Key Spec" }},
})
local calls_before_no_key_boot = #calls
models.prefer_top_api_key_on_boot("no-key-spec/model")
T("boot skips probe for providers without API keys",
  #calls == calls_before_no_key_boot)

-- Mask edges (shared helper)
T("mask hides short keys", shared.mask("ab") == "****")
T("mask keeps last four of long keys",
  shared.mask("abcdefghijklmnop"):sub(-4) == "mnop"
  and not shared.mask("abcdefghijklmnop"):find("abcd", 1, true))

-- Shared test_all without model/keys
local none, err = shared.test_all("no-key-spec")
T("test-all without keys returns guidance", none == nil and type(err) == "string")

-- Contrato: subagentes não devem chamar prefer_top no boot (agent/context.lua)
local ctx_src = assert(io.open("agent/context.lua", "r")):read("*a")
T("primary session boot gates prefer_top behind not is_subagent",
  ctx_src:find("not opts%.is_subagent") ~= nil
  and ctx_src:find("prefer_top_api_key_on_boot") ~= nil)

validate.test_connection = original_test
os.remove(store.PATH)
os.execute("rmdir " .. dir .. " 2>/dev/null")
print(string.format("\nFALLBACK KEYS: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
