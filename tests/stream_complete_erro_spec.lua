package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local f = assert(io.open("agent/loop.lua", "r")); local src = f:read("*a"); f:close()
T(src:find('return "", 0, false, false, false, ""', 1, true) ~= nil, "stream_complete false")
T(src:find("show_api_error") ~= nil, "show_api_error")
f = assert(io.open("agent/api/request_stream/streamer/parte_1.lua", "r")); local s2 = f:read("*a"); f:close()
T(not s2:find("got_data = false"), "nao zera got_data")
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
