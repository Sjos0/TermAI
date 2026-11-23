package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local captured = nil
package.loaded["ui"] = {
  clear_retry_lines = function() end,
  show_api_error = function(message) captured = message end,
}
local attempts = require("agent.api.request_stream.streamer.key_attempts")
local tracker_ctx = { active = { ref = "provider/model", api_key_index = 2 } }
attempts.begin(tracker_ctx)
attempts.start_key(tracker_ctx, 1)
attempts.start_attempt(tracker_ctx, 3)
attempts.end_key(tracker_ctx)
attempts.finish(tracker_ctx, 2)
assert(tracker_ctx._key_attempt_summaries[1].keys[1].index == 2,
  "tracker must preserve the actual active key index")
assert(tracker_ctx._key_attempt_summaries[1].keys[1].attempts == 3,
  "tracker must preserve attempts used for each key")

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
assert(captured:find("provider-a/model-a", 1, true), "summary must identify the primary model")
assert(captured:find("1/2 (10 tent.)", 1, true), "summary must include per-key attempt counts")
assert(captured:find("provider-b/model-b", 1, true), "summary must include macro fallbacks")
print("FALLBACK SUMMARY: 5 assertions passed")
