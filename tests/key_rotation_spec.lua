package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
table.unpack = table.unpack or unpack

local rotation = require("agent.api.request_stream.streamer.key_rotation")
local pass, fail = 0, 0
local function T(name, ok)
  if ok then pass = pass + 1; print("  PASS " .. name)
  else fail = fail + 1; print("  FAIL " .. name) end
end

-- --- record ---
local recorded = nil
local models_record = {
  record_api_key = function(provider, index, success)
    recorded = { provider, index, success }
  end,
}
rotation.record(models_record, {
  provider = "provider-a", api_key_index = 1, api_key_count = 2,
}, false)
T("record failure metadata", recorded
  and recorded[1] == "provider-a" and recorded[2] == 1 and recorded[3] == false)

recorded = "untouched"
rotation.record(models_record, { provider = "p", api_key_index = 1, api_key_count = 0 }, true)
T("record skips when api_key_count < 1", recorded == "untouched")

rotation.record(models_record, nil, true)
T("record skips nil active", recorded == "untouched")

-- --- rotate ---
local rotated = false
local models_rotate = {
  preview_api_key_rotation = function(provider, index)
    rotated = provider == "provider-a" and index == 1
    return "second-secret", 2, 2, 1
  end,
  resolve = function(ref, key_index)
    T("candidate resolution receives preview key index", key_index == 2)
    return {
      ref = ref, provider = "provider-a", api_key = "second-secret",
      api_key_index = 2, api_key_count = 2,
    }
  end,
  commit_api_key_rotation = function(provider, index, previous)
    return provider == "provider-a" and index == 2 and previous == 1
  end,
}
local ctx = {
  active = {
    ref = "provider-a/model-a", provider = "provider-a",
    api_key_index = 1, api_key_count = 2,
  },
  cfg = { agents = { defaults = { request = { fallback_transparency = false } } } },
}
T("rotate resolves next key", rotation.rotate(models_rotate, ctx) == true)
T("context switches to next key", rotated
  and ctx.active.api_key == "second-secret" and ctx.active.api_key_index == 2)

local models_no_next = {
  preview_api_key_rotation = function() return nil, 1, 1 end,
  resolve = function() return { api_key = "only" } end,
  commit_api_key_rotation = function() return true end,
}
ctx.active = { ref = "p/m", provider = "p", api_key_index = 1, api_key_count = 1 }
T("rotate returns false when no next key", rotation.rotate(models_no_next, ctx) == false)

local resolve_commit_called, resolve_failed_index = false, nil
local models_resolve_nil = {
  preview_api_key_rotation = function() return "k", 2, 2, 1 end,
  resolve = function(_, key_index) resolve_failed_index = key_index; return nil end,
  commit_api_key_rotation = function()
    resolve_commit_called = true
    return true
  end,
}
ctx.active = { ref = "p/m", provider = "p", api_key_index = 1, api_key_count = 2 }
T("rotate returns false when resolve fails", rotation.rotate(models_resolve_nil, ctx) == false)
T("resolve failure uses the preview index", resolve_failed_index == 2)
T("resolve failure never commits the active-key index", resolve_commit_called == false)

local persistence_commit_called = false
local models_commit_failure = {
  preview_api_key_rotation = function() return "k", 2, 2, 1 end,
  resolve = function() return { api_key = "k", api_key_index = 2 } end,
  commit_api_key_rotation = function()
    persistence_commit_called = true
    return false
  end,
}
ctx.active = { ref = "p/m", provider = "p", api_key_index = 1, api_key_count = 2 }
T("rotate returns false when persistence fails",
  rotation.rotate(models_commit_failure, ctx) == false)
T("failed commit does not switch request context",
  persistence_commit_called and ctx.active.api_key_index == 1)

-- transparency message is routed through the shared spinner UI
local notice = nil
package.loaded["ui.spinner"] = {
  show_key_rotation = function(provider, failed, next_index, total)
    notice = { provider, failed, next_index, total }
  end,
}
local models_t = {
  preview_api_key_rotation = function() return "k2", 2, 3, 1 end,
  resolve = function(ref, key_index)
    return { ref = ref, provider = "prov", api_key = "k2", api_key_index = key_index, api_key_count = 3 }
  end,
  commit_api_key_rotation = function(provider, index, previous)
    return provider == "prov" and index == 2 and previous == 1
  end,
}
ctx = {
  active = { ref = "prov/m", provider = "prov", api_key_index = 1, api_key_count = 3 },
  cfg = { agents = { defaults = { request = {} } } }, -- default transparency on
}
T("transparency emits message by default", rotation.rotate(models_t, ctx) == true)
T("transparency uses shared UI notice without passing secrets",
  notice and notice[1] == "prov" and notice[2] == 1
  and notice[3] == 2 and notice[4] == 3)

notice = nil
ctx = {
  active = { ref = "prov/m", provider = "prov", api_key_index = 1, api_key_count = 3 },
  cfg = { agents = { defaults = { request = { fallback_transparency = false } } } },
}
rotation.rotate(models_t, ctx)
T("transparency can be disabled", notice == nil)
package.loaded["ui.spinner"] = nil

-- --- endpoint_label ---
local utils_full = {
  redact_endpoint = function(ep) return "REDACTED:" .. tostring(ep) end,
}
T("endpoint_label without multi-key omits index",
  rotation.endpoint_label({ endpoint = "https://x", api_key_count = 1 }, utils_full)
    == "REDACTED:https://x")
T("endpoint_label with multi-key appends index",
  rotation.endpoint_label({
    endpoint = "https://x", api_key_index = 2, api_key_count = 3,
  }, utils_full) == "REDACTED:https://x [chave 2/3]")
T("endpoint_label tolerates missing utils.redact_endpoint",
  rotation.endpoint_label({ endpoint = "raw", api_key_count = 1 }, {}) == "raw")

-- --- redact_secret ---
local utils_redact = {
  redact_secret = function(value, secret)
    return tostring(value):gsub(secret, "[REDACTED]")
  end,
}
T("redact_secret uses utils when present",
  rotation.redact_secret(utils_redact, "err: tok", "tok") == "err: [REDACTED]")
T("redact_secret falls back without utils helper",
  rotation.redact_secret({}, "plain", "tok") == "plain")

-- --- handle_sync_result ---
local fb_called, fb_final = false, false
local fb = {
  tentar_fallbacks = function()
    fb_called = true
    local t = { "recovered", false, true, "", nil }
    t.n = 5
    return t, nil
  end,
  falha_final = function()
    fb_final = true
    return "final-fail", false, false, ""
  end,
}
local r1, o1 = rotation.handle_sync_result(fb, {}, "user",
  "[ERRO_OVERFLOW] too big", {}, "reason")
T("handle_sync_result propagates overflow",
  r1 == "[ERRO_OVERFLOW] too big" and o1 == true and not fb_called)

fb_called = false
local r2 = rotation.handle_sync_result(fb, {}, "user",
  "[ERRO DE COMUNICACAO] down", {}, "reason")
T("handle_sync_result routes communication error to macro fallback",
  r2 == "recovered" and fb_called)

fb_called, fb_final = false, false
fb.tentar_fallbacks = function() return nil, "no-fallback" end
local r3 = rotation.handle_sync_result(fb, {}, "user",
  "[ERRO DE COMUNICACAO] down", {}, "reason")
T("handle_sync_result uses falha_final when macro exhausted",
  r3 == "final-fail" and fb_final)

local r4, o4, s4 = rotation.handle_sync_result(fb, {}, "user",
  "ok-content", {}, "r", nil)
T("handle_sync_result passes success through",
  r4 == "ok-content" and o4 == false and s4 == true)

print(string.format("\nKEY ROTATION: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
