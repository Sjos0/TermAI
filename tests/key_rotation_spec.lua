package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local rotation = require("agent.api.request_stream.streamer.key_rotation")
local recorded, rotated = nil, false
local models = {
  record_api_key = function(provider, index, success)
    recorded = { provider, index, success }
  end,
  rotate_api_key = function(provider, index)
    rotated = provider == "provider-a" and index == 1
    return "second-secret", 2, 2
  end,
  resolve = function(ref)
    return { ref = ref, provider = "provider-a", api_key = "second-secret",
      api_key_index = 2, api_key_count = 2 }
  end,
}
local ctx = {
  active = { ref = "provider-a/model-a", provider = "provider-a",
    api_key_index = 1, api_key_count = 2 },
  cfg = { agents = { defaults = { request = { fallback_transparency = false } } } },
}
rotation.record(models, ctx.active, false)
assert(recorded[1] == "provider-a" and recorded[2] == 1 and recorded[3] == false,
  "key failure metadata must be recorded")
assert(rotation.rotate(models, ctx, { max_retries = 3 }) == true,
  "rotation should resolve the next active key")
assert(rotated and ctx.active.api_key == "second-secret" and ctx.active.api_key_index == 2,
  "context should switch to the next key without exposing it")
print("KEY ROTATION: 3 assertions passed")
