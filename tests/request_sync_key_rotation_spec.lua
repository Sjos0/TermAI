package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local responses = { "failure", "success" }
local response_index = 0
local writes = {}
local records = {}
local error_records = 0

package.loaded.json = {
  decode = function(body)
    if body == "failure" then return { error = { message = "invalid key", code = 401 } } end
    if body == "success" then
      return { choices = { { message = { content = "sync recovered" } } } }
    end
    error("unexpected response: " .. tostring(body))
  end,
}
package.loaded["agent.api.utils"] = {
  get_req_cfg = function() return { max_retries = 2, timeout = 10, idle_timeout = 5 } end,
  build_auth = function(active) return " -H 'Authorization: Bearer " .. active.api_key .. "'" end,
  make_tmp_path = function() return "/tmp/request-sync-key-rotation" end,
  wait_time = function() return 0 end,
  ensure_tokens = function() end,
  strip_thinking_tags = function(value) return value end,
  estimate_tokens = function() return 1 end,
  redact_secret = function(value) return tostring(value or "") end,
  redact_endpoint = function(value) return value end,
}
package.loaded["agent.api.payload"] = { build_payload = function() return "payload" end }
package.loaded["agent.api.request_stream.error_log"] = {
  should_retry = function(message)
    if message:find("invalid key", 1, true) then return false, 401 end
    return true
  end,
  record = function() error_records = error_records + 1 end,
}
package.loaded.models = {
  record_api_key = function(provider, index, success)
    records[#records + 1] = { provider = provider, index = index, success = success }
  end,
  rotate_api_key = function(provider, index)
    assert(provider == "provider-a" and index == 1)
    return "key-two", 2, 2
  end,
  resolve = function(ref)
    return { ref = ref, provider = "provider-a", api_key = "key-two",
      api_key_index = 2, api_key_count = 2, endpoint = "https://example.invalid", auth_style = "bearer" }
  end,
}

local old_open, old_popen, old_remove, old_execute = io.open, io.popen, os.remove, os.execute
io.open = function()
  return { write = function(_, value) writes[#writes + 1] = value end, close = function() end }
end
io.popen = function()
  response_index = response_index + 1
  local value = responses[response_index]
  return { read = function() return value end, close = function() return true end }
end
os.remove = function() return true end
os.execute = function() return true end

local sync = require("agent.api.request_sync")
local ctx = {
  active = { ref = "provider-a/model-a", provider = "provider-a", api_key = "key-one",
    api_key_index = 1, api_key_count = 2, endpoint = "https://example.invalid", auth_style = "bearer" },
  cfg = { agents = { defaults = { request = { fallback_transparency = false } } } },
  msgs = {}, tokens = 0,
}
local result = sync.pensar_sync(ctx, nil, "user")

io.open, io.popen, os.remove, os.execute = old_open, old_popen, old_remove, old_execute

assert(result == "sync recovered", "sync request should succeed with the next API key")
assert(response_index == 2, "non-retryable auth failure should rotate after the first key")
assert(ctx.active.api_key_index == 2 and ctx.active.api_key == "key-two", "context should hold the rotated key")
assert(#records == 2 and records[1].success == false and records[2].success == true,
  "failure and success health metadata should be recorded")
assert(error_records == 1, "failed key attempt should be recorded")
assert(#writes == 2, "payload should be sent once for each key")
print("REQUEST SYNC KEY ROTATION: 6 assertions passed")
