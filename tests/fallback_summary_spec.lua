package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local pass, fail = 0, 0
local function T(name, ok)
  if ok then pass = pass + 1; print("  PASS " .. name)
  else fail = fail + 1; print("  FAIL " .. name) end
end

local captured = nil
package.loaded["ui"] = {
  clear_retry_lines = function() end,
  show_api_error = function(message) captured = message end,
}

local attempts = require("agent.api.request_stream.streamer.key_attempts")

-- Tracker básico
local tracker_ctx = { active = { ref = "provider/model", api_key_index = 2 } }
attempts.begin(tracker_ctx)
attempts.start_key(tracker_ctx, 1)
attempts.start_attempt(tracker_ctx, 3)
attempts.end_key(tracker_ctx)
attempts.finish(tracker_ctx, 2)
T("tracker preserves actual active key index",
  tracker_ctx._key_attempt_summaries[1].keys[1].index == 2)
T("tracker preserves attempts used for each key",
  tracker_ctx._key_attempt_summaries[1].keys[1].attempts == 3)

-- Múltiplas chaves no mesmo modelo
local multi = { active = { ref = "p/m", api_key_index = 1 } }
attempts.begin(multi)
attempts.start_key(multi, 1)
attempts.start_attempt(multi, 5)
attempts.end_key(multi)
multi.active.api_key_index = 2
attempts.start_key(multi, 2)
attempts.start_attempt(multi, 2)
attempts.end_key(multi)
attempts.finish(multi, 2)
T("tracker accumulates per-key rows before finish",
  #multi._key_attempt_summaries[1].keys == 2
  and multi._key_attempt_summaries[1].keys[1].attempts == 5
  and multi._key_attempt_summaries[1].keys[2].index == 2)

-- _fallback_suppress não zera resumos anteriores (macro encadeado)
local suppressed = {
  _fallback_suppress = true,
  _key_attempt_summaries = {
    { model = "already/there", total = 1, keys = { { index = 1, attempts = 1 } } },
  },
  active = { ref = "next/model", api_key_index = 1 },
}
attempts.begin(suppressed)
attempts.start_key(suppressed, 1)
attempts.start_attempt(suppressed, 4)
attempts.end_key(suppressed)
attempts.finish(suppressed, 1)
T("begin with fallback_suppress keeps prior summaries",
  #suppressed._key_attempt_summaries == 2
  and suppressed._key_attempt_summaries[1].model == "already/there"
  and suppressed._key_attempt_summaries[2].model == "next/model")

-- Mensagem final compacta
local build = require("agent.api.request_stream.streamer.fallback")
local fallback = build({})
local ctx = {
  msgs = {},
  _key_attempt_summaries = {
    { model = "provider-a/model-a", total = 2, keys = {
      { index = 1, attempts = 10 }, { index = 2, attempts = 10 },
    } },
    { model = "provider-b/model-b", total = 1, keys = {
      { index = 1, attempts = 10 },
    } },
  },
}
fallback.falha_final(ctx, { max_retries = 10, keys_total = 2 }, "HTTP 429")
T("summary identifies the primary model",
  captured:find("provider-a/model-a", 1, true) ~= nil)
T("summary includes per-key attempt counts",
  captured:find("1/2 (10 tent.)", 1, true) ~= nil)
T("summary includes macro fallbacks",
  captured:find("provider-b/model-b", 1, true) ~= nil)
T("summary stays on one compact line for mobile TUI",
  not captured:find("\n", 1, true) or select(2, captured:gsub("\n", "\n")) <= 2)

-- Sem resumos: mensagem base ainda funciona
captured = nil
fallback.falha_final({ msgs = {} }, { max_retries = 3 }, "timeout")
T("falha_final without summaries still reports base error",
  type(captured) == "string" and captured:find("timeout", 1, true) ~= nil)

print(string.format("\nFALLBACK SUMMARY: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
