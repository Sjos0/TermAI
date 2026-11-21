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
  rotate_api_key = function(provider, index)
    rotated = provider == "provider-a" and index == 1
    return "second-secret", 2, 2
  end,
  resolve = function(ref)
    return {
      ref = ref, provider = "provider-a", api_key = "second-secret",
      api_key_index = 2, api_key_count = 2,
    }
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
  rotate_api_key = function() return nil, 1, 1 end,
  resolve = function() return { api_key = "only" } end,
}
ctx.active = { ref = "p/m", provider = "p", api_key_index = 1, api_key_count = 1 }
T("rotate returns false when no next key", rotation.rotate(models_no_next, ctx) == false)

local models_resolve_nil = {
  rotate_api_key = function() return "k", 2, 2 end,
  resolve = function() return nil end,
}
ctx.active = { ref = "p/m", provider = "p", api_key_index = 1, api_key_count = 2 }
T("rotate returns false when resolve fails", rotation.rotate(models_resolve_nil, ctx) == false)

-- transparency message (enabled by default when not false)
local written = {}
local old_write, old_flush = io.write, io.flush
io.write = function(s) written[#written + 1] = s end
io.flush = function() end
local models_t = {
  rotate_api_key = function() return "k2", 2, 3 end,
  resolve = function(ref)
    return { ref = ref, provider = "prov", api_key = "k2", api_key_index = 2, api_key_count = 3 }
  end,
}
ctx = {
  active = { ref = "prov/m", provider = "prov", api_key_index = 1, api_key_count = 3 },
  cfg = { agents = { defaults = { request = {} } } }, -- default transparency on
}
T("transparency emits message by default", rotation.rotate(models_t, ctx) == true)
local joined = table.concat(written, "")
T("transparency mentions key indices, not secrets",
  joined:find("chave 1 falhou", 1, true) ~= nil
  and joined:find("chave 2/3", 1, true) ~= nil
  and joined:find("k2", 1, true) == nil)

written = {}
ctx = {
  active = { ref = "prov/m", provider = "prov", api_key_index = 1, api_key_count = 3 },
  cfg = { agents = { defaults = { request = { fallback_transparency = false } } } },
}
rotation.rotate(models_t, ctx)
T("transparency can be disabled", #written == 0)
io.write, io.flush = old_write, old_flush

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
