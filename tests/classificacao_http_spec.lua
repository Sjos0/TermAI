-- tests/classificacao_http_spec.lua — #280: 400 não repete; 429/503 repetem.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local error_log = require("agent.api.request_stream.error_log")

local r, c
r, c = error_log.should_retry("[400] bad request", "")
T(r == false and c == 400, "400 não repete (got retry=" .. tostring(r) .. " code=" .. tostring(c) .. ")")
r, c = error_log.should_retry("rate limit", '{"status": 429}')
T(r == true and c == 429, "429 repete")
r, c = error_log.should_retry("unavailable", "HTTP 503")
T(r == true and c == 503, "503 repete")
r, c = error_log.should_retry("Sem resposta do servidor", "")
T(r == true and c == nil, "sem status: repete por padrão")
r, c = error_log.should_retry("status=401 unauthorized", "")
T(r == false and c == 401, "401 não repete")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
