package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local models = require("models")
local store = require("models.store")
local validate = require("models.validate")
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

local ok_one = models.test_api_key("fallback-spec", "fallback-spec/model", 1)
local _, active_index = models.active_api_key("fallback-spec")
assert(ok_one == false and active_index == 3,
  "individual key test must not change active key")

local shared = require("commands.config.fallback_keys")
local results, invalid = shared.test_all("fallback-spec")
_, active_index = models.active_api_key("fallback-spec")
assert(results and #results == 3 and #invalid == 2,
  "test-all must return every result and failed indices")
assert(active_index == 3, "test-all must preserve the active key")
assert(calls[1].options.connect_timeout == 2 and calls[1].options.max_time == 6,
  "key tests must use bounded connection timeouts")

local recovered, recovered_index = models.prefer_top_api_key_on_boot("fallback-spec/model", {
  connect_timeout = 1, max_time = 3,
})
local active_key
active_key, active_index = models.active_api_key("fallback-spec")
assert(recovered and recovered_index == 2 and active_index == 2 and active_key == "key-two",
  "boot must select the first healthy key after the preferred key fails")
local calls_before_preferred_recheck = #calls
local kept_preferred = models.prefer_top_api_key_on_boot("fallback-spec/model", {
  connect_timeout = 1, max_time = 3,
})
_, active_index = models.active_api_key("fallback-spec")
assert(not kept_preferred and active_index == 2
  and #calls == calls_before_preferred_recheck + 1,
  "boot must keep the saved preferred key when it is healthy")

local rows = shared.dashboard("fallback-spec")
assert(#rows == 3 and rows[2].state == "OK" and rows[2].active,
  "dashboard must expose health and active state")
assert(#rows[2].masked <= 12, "dashboard key masks must stay compact on narrow terminals")

models.add_provider({
  id = "no-key-spec", baseUrl = "https://example.invalid/v1",
  api = "openai-completions", apiKeys = {},
  models = {{ id = "model", name = "No Key Spec" }},
})
local calls_before_no_key_boot = #calls
models.prefer_top_api_key_on_boot("no-key-spec/model")
assert(#calls == calls_before_no_key_boot,
  "boot health checks must not send a probe for providers without API keys")

validate.test_connection = original_test
os.remove(store.PATH)
os.execute("rmdir " .. dir .. " 2>/dev/null")
print("FALLBACK KEYS: 8 assertions passed")
