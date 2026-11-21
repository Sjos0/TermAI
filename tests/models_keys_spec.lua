package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local json = require("json")
local models = require("models")
local store = require("models.store")
local dir = "/tmp/termai_models_keys_spec"
store.PATH = dir .. "/models.json"
os.execute("mkdir -p " .. dir)
os.remove(store.PATH)
store._data = nil

local pass, fail = 0, 0
local function T(name, ok)
  if ok then pass = pass + 1; print("  PASS " .. name)
  else fail = fail + 1; print("  FAIL " .. name) end
end

models.load()
local added = models.add_provider({
  id = "spec-provider", baseUrl = "https://example.invalid/v1",
  apiKey = "key-one-123", api = "openai-completions",
  models = {{ id = "spec-model", name = "Spec Model" }},
})
T("add provider accepts legacy apiKey", added == true)
local keys = models.list_api_keys("spec-provider")
T("legacy apiKey becomes apiKeys list", #keys == 1 and keys[1].key == "key-one-123")
T("legacy apiKey is active", keys[1] and keys[1].active == true)

local duplicate, duplicate_error = models.add_api_key("spec-provider", "key-one-123")
T("duplicate key is rejected", duplicate == false and duplicate_error ~= nil)
local second = models.add_api_key("spec-provider", "key-two-456")
T("second key is added", second == true and #models.list_api_keys("spec-provider") == 2)
local resolved = models.resolve("spec-provider/spec-model")
T("model resolution exposes active key and count", resolved.api_key == "key-one-123"
  and resolved.api_key_index == 1 and resolved.api_key_count == 2)
T("candidate resolution rejects invalid key indices",
  models.resolve("spec-provider/spec-model", 99) == nil)
local unsafe = models.add_api_key("spec-provider", "bad\"; rm -rf /")
T("unsafe key input is rejected", unsafe == false)

local rotated, index, total, previous_index = models.preview_api_key_rotation("spec-provider", 1)
T("rotation previews next key without mutating active state",
  rotated == "key-two-456" and index == 2 and total == 2 and previous_index == 1)
local active, active_index = models.active_api_key("spec-provider")
T("preview leaves persisted active key unchanged", active == "key-one-123" and active_index == 1)
local preview = models.resolve("spec-provider/spec-model", index)
T("model resolution can preview the next key", preview.api_key == "key-two-456"
  and preview.api_key_index == 2)
local invalid_preview = models.resolve("spec-provider/missing-model", index)
local unchanged_key, unchanged_index = models.active_api_key("spec-provider")
T("failed candidate resolution leaves active key unchanged",
  invalid_preview == nil and unchanged_key == "key-one-123" and unchanged_index == 1)
T("rotation commit succeeds after resolution",
  models.commit_api_key_rotation("spec-provider", index, previous_index) == true)
active, active_index = models.active_api_key("spec-provider")
T("committed rotation persists active key", active == "key-two-456" and active_index == 2)
resolved = models.resolve("spec-provider/spec-model")
T("model resolution follows committed key", resolved.api_key == "key-two-456"
  and resolved.api_key_index == 2)
local failed_preview, failed_index, _, failed_previous = models.preview_api_key_rotation("spec-provider", 2)
local save_before_failure = store.save
store.save = function() return false end
local commit_failed = models.commit_api_key_rotation("spec-provider", failed_index, failed_previous)
store.save = save_before_failure
active, active_index = models.active_api_key("spec-provider")
T("failed rotation persistence restores in-memory active key",
  failed_preview == "key-one-123" and commit_failed == false
  and active == "key-two-456" and active_index == 2)
local stale_preview, stale_index, _, stale_previous = models.preview_api_key_rotation("spec-provider", 2)
models.set_active_api_key("spec-provider", 1)
local stale_commit = models.commit_api_key_rotation("spec-provider", stale_index, stale_previous)
active, active_index = models.active_api_key("spec-provider")
T("stale rotation cannot overwrite a newer active-key selection",
  stale_preview == "key-one-123" and stale_commit == false
  and active == "key-one-123" and active_index == 1)
models.set_active_api_key("spec-provider", 2)

models.record_api_key("spec-provider", 2, true)
keys = models.list_api_keys("spec-provider")
T("success metadata is persisted", keys[2].last_ok ~= nil and keys[2].last_error_at == nil)
models.record_api_key("spec-provider", 2, false)
keys = models.list_api_keys("spec-provider")
T("failure metadata is persisted", keys[2].last_error_at ~= nil)
local invalid_active = models.set_active_api_key("spec-provider", 1.5)
T("fractional active-key index is rejected", invalid_active == false)
local updated = models.update_api_key("spec-provider", "key-two-updated")
keys = models.list_api_keys("spec-provider")
T("legacy update replaces only active key", updated == true and #keys == 2
  and keys[1].key == "key-one-123" and keys[2].key == "key-two-updated" and keys[2].active)
local unsafe_update = models.update_api_key("spec-provider", "bad;key")
T("unsafe replacement is rejected", unsafe_update == false)

local removed = models.remove_api_key("spec-provider", 2)
keys = models.list_api_keys("spec-provider")
T("key removal preserves remaining key", removed == true and #keys == 1 and keys[1].key == "key-one-123")
local original_save, save_count = store.save, 0
store.save = function() save_count = save_count + 1; return original_save() end
models.record_api_key("spec-provider", 1, true)
models.record_api_key("spec-provider", 1, true)
models.record_api_key("spec-provider", 1, false)
models.record_api_key("spec-provider", 1, false)
models.record_api_key("spec-provider", 1, true)
store.save = original_save
T("health metadata writes only on state transitions", save_count == 3)
models.add_provider({ id = "health-spec", baseUrl = "https://health.invalid",
  apiKey = "health-key", api = "openai-completions", models = {{ id = "model" }} })
local original_date, day, daily_saves = os.date, "2026-11-20", 0
os.date = function() return day .. "T12:00:00Z" end
store.save = function() daily_saves = daily_saves + 1; return original_save() end
models.record_api_key("health-spec", 1, true)
models.record_api_key("health-spec", 1, true)
day = "2026-11-21"
models.record_api_key("health-spec", 1, true)
os.date, store.save = original_date, original_save
T("health metadata refreshes at most once per day", daily_saves == 2)

-- A legacy file is upgraded and rewritten on first load, without losing the key.
local legacy = { active = "legacy/model", providers = {
  legacy = { baseUrl = "https://legacy.invalid/v1", apiKey = "legacy-secret",
    api = "openai-completions", models = {{ id = "model" }} },
} }
local f = assert(io.open(store.PATH, "w")); f:write(json.encode(legacy)); f:close()
store._data = nil
models.load()
f = assert(io.open(store.PATH, "r")); local saved = json.decode(f:read("*a")); f:close()
T("legacy config is migrated and persisted", saved.providers.legacy.apiKeys[1].key == "legacy-secret")
T("legacy field remains compatible", saved.providers.legacy.apiKey == "legacy-secret")

models.add_provider({ id = "remove-spec", baseUrl = "https://remove.invalid",
  api = "openai-completions", apiKeys = { "key-a", "key-b", "key-c" },
  models = {{ id = "model" }} })
models.set_active_api_key("remove-spec", 3)
models.remove_api_key("remove-spec", 1)
local remaining, remaining_index = models.active_api_key("remove-spec")
T("removing a key before active preserves active key", remaining == "key-c" and remaining_index == 2)
models.remove_api_key("remove-spec", 2)
remaining, remaining_index = models.active_api_key("remove-spec")
T("removing the active last key selects a valid next key", remaining == "key-b" and remaining_index == 1)

local google_added = models.add_provider({
  id = "google", baseUrl = "https://generativelanguage.googleapis.com/v1beta",
  apiKey = "google-key-one", api = "google-generative-ai",
  models = {{ id = "gemini-test", name = "Gemini Test" }},
})
models.add_api_key("google", "google-key-two")
local google_active = models.resolve("google/gemini-test")
T("Google endpoint uses active key", google_added and google_active.endpoint:find("key=google-key-one", 1, true) ~= nil)
local google_next, google_index, _, google_previous = models.preview_api_key_rotation("google", 1)
local google_preview = models.resolve("google/gemini-test", google_index)
T("Google endpoint previews the next key", google_next == "google-key-two"
  and google_preview.endpoint:find("key=google-key-two", 1, true) ~= nil)
T("Google rotation commits only after preview resolution",
  models.commit_api_key_rotation("google", google_index, google_previous) == true)
google_active = models.resolve("google/gemini-test")
T("Google endpoint updates after committed rotation", google_active.endpoint:find("key=google-key-two", 1, true) ~= nil)

os.remove(store.PATH)
os.execute("rmdir " .. dir .. " 2>/dev/null")
print(string.format("\nMODELS KEYS: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
