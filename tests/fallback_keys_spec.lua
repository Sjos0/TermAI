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

-- B) Ciclo de topo no boot
local events = {}
local before_boot = #calls
local recovered, recovered_index = models.prefer_top_api_key_on_boot("fallback-spec/model", {
  connect_timeout = 1, max_time = 3,
  on_progress = function(event, payload)
    events[#events + 1] = { event = event, payload = payload }
  end,
})
local active_key
active_key, active_index = models.active_api_key("fallback-spec")
T("boot recovers nearest healthy top when previous keys include a good one",
  recovered and recovered_index == 2 and active_index == 2 and active_key == "key-two"
  and #calls == before_boot + 2)
T("boot emits progress start and probe events",
  events[1] and events[1].event == "start"
  and events[2] and events[2].event == "probe"
  and events[#events] and events[#events].event == "recovered")

-- ativa em 2; key1 OK → sobe ao topo
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

-- Já no topo: zero probes
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

-- Ativa em 3; todas as anteriores ruins → mantém 3 e só testa 1..2
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

-- Orçamento: max_previous limita probes mesmo com N>3 anteriores
models.add_provider({
  id = "many-keys-spec", baseUrl = "https://example.invalid/v1",
  api = "openai-completions",
  apiKeys = { "k1", "k2", "k3", "k4", "k5" },
  models = {{ id = "model", name = "Many" }},
})
models.set_active("many-keys-spec/model")
models.set_active_api_key("many-keys-spec", 5)
local many_calls = 0
validate.test_connection = function(active, options)
  many_calls = many_calls + 1
  return false, "down"
end
models.prefer_top_api_key_on_boot("many-keys-spec/model", {
  connect_timeout = 1, max_time = 3, max_previous = 3,
})
local _, many_active = models.active_api_key("many-keys-spec")
T("boot respects max_previous budget of 3 probes",
  many_calls == 3 and many_active == 5)

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

-- G) A listagem principal mantém identidade e saúde em linhas distintas.
local cli_fallback = assert(io.open("commands/config_cli/menus/request/fallback.lua", "r")):read("*a")
local tui_fallback = assert(io.open("commands/config/menus/request/fallback.lua", "r")):read("*a")
T("CLI fallback renders structured dashboard rows",
  cli_fallback:find("keys.dashboard(provider_id)", 1, true) ~= nil
  and cli_fallback:find("item.last", 1, true) ~= nil)
T("TUI fallback renders structured dashboard rows",
  tui_fallback:find("keys.dashboard(provider_id)", 1, true) ~= nil
  and tui_fallback:find("item.last", 1, true) ~= nil)
T("fallback health metadata is no longer concatenated into key identity",
  not cli_fallback:find("health%.label%(item%)")
  and not tui_fallback:find("health%.label%(item%)"))

-- G2) Contrato estrutural do dashboard + layout de duas linhas (Issue #376).
-- Trava: identidade na 1ª linha; saúde/data na 2ª indentada; sem concatenação.
do
  local rows_g = shared.dashboard("fallback-spec")
  T("dashboard rows expose discrete identity fields",
    #rows_g >= 1
    and type(rows_g[1].index) == "number"
    and type(rows_g[1].masked) == "string"
    and type(rows_g[1].state) == "string"
    and type(rows_g[1].active) == "boolean"
    and type(rows_g[1].last) == "string")

  local buf = {}
  for _, item in ipairs(rows_g) do
    buf[#buf + 1] = string.format("  %d. %s  %s%s",
      item.index, item.masked, item.state, item.active and " [ATIVA]" or "")
    buf[#buf + 1] = "     " .. item.last
  end

  local identity_ok, health_ok = true, true
  for i = 1, #rows_g do
    local id_line = buf[i * 2 - 1]
    local health_line = buf[i * 2]
    local row = rows_g[i]
    if not id_line:match("^%s*%d+%.") then identity_ok = false end
    if id_line:find("último", 1, true) or id_line:find("última", 1, true)
        or id_line:find("sem teste", 1, true) then
      identity_ok = false
    end
    if not health_line:match("^%s%s%s%s%s") then health_ok = false end
    if not health_line:find(row.last, 1, true) then health_ok = false end
  end
  T("manage_keys layout keeps identity free of health markers", identity_ok)
  T("manage_keys layout puts health on indented second line", health_ok)

  local active_row
  for _, r in ipairs(rows_g) do if r.active then active_row = r break end end
  T("active row last is non-empty structured label",
    active_row ~= nil and type(active_row.last) == "string" and #active_row.last > 0)
end

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

T("mask hides short keys", shared.mask("ab") == "****")
T("mask keeps last four of long keys",
  shared.mask("abcdefghijklmnop"):sub(-4) == "mnop"
  and not shared.mask("abcdefghijklmnop"):find("abcd", 1, true))

local none, err = shared.test_all("no-key-spec")
T("test-all without keys returns guidance", none == nil and type(err) == "string")

local ctx_src = assert(io.open("agent/context.lua", "r")):read("*a")
T("primary session boot gates prefer_top behind not is_subagent",
  ctx_src:find("not opts%.is_subagent") ~= nil
  and ctx_src:find("prefer_top_api_key_on_boot") ~= nil)
T("context boot passes max_previous and on_progress wiring",
  ctx_src:find("max_previous%s*=%s*3") ~= nil
  and ctx_src:find("on_progress") ~= nil
  and ctx_src:find("max_wall_seconds") ~= nil)

-- Item E: texto interativo de Atualizar API Key
local update_src = assert(io.open("commands/models/providers/update_key.lua", "r")):read("*a")
T("update_key UI states active-only replacement",
  update_src:find("só a chave ativa") ~= nil
  and update_src:find("preserva as demais") ~= nil
  and update_src:find("Chave ativa atualizada; as demais foram preservadas") ~= nil)

-- parte_1: sem empacotamento com ; nas linhas de key_attempts
local parte1 = assert(io.open("agent/api/request_stream/streamer/parte_1.lua", "r")):read("*a")
T("parte_1 keeps key_attempts calls on their own lines",
  parte1:find("key_attempts%.begin%(ctx%)") ~= nil
  and not parte1:find("get_req_cfg%(ctx%);%s*key_attempts")
  and not parte1:find("key_attempts%.finish%(ctx, key_rounds%);%s*local fb_res"))
local attempt_src = assert(io.open("agent/api/request_stream/streamer/stream_attempt.lua", "r")):read("*a")
T("stream_attempt guards tmp file open",
  attempt_src:find('io%.open%(tmp_path, "w"%)') ~= nil
  and attempt_src:find("if not tmp then") ~= nil)
T("parte_1 finishes key_attempts on success path",
  parte1:find("key_attempts%.end_key%(ctx%)") ~= nil
  and parte1:find("key_attempts%.finish%(ctx, key_rounds%)") ~= nil)

-- key_rotation log on refused commit
local kr = assert(io.open("agent/api/request_stream/streamer/key_rotation.lua", "r")):read("*a")
T("key_rotation logs when commit is refused",
  kr:find("Rotação recusada") ~= nil)

validate.test_connection = original_test
os.remove(store.PATH)
os.execute("rmdir " .. dir .. " 2>/dev/null")
print(string.format("\nFALLBACK KEYS: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
