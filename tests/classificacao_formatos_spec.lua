package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local el = require("agent.api.request_stream.error_log")
local function no(body, label)
  local r, c = el.should_retry("err", body)
  T(r == false, label .. " não repete (retry=" .. tostring(r) .. " c=" .. tostring(c) .. ")")
end
local function yes(body, label)
  local r, c = el.should_retry("err", body)
  T(r == true, label .. " repete (retry=" .. tostring(r) .. " c=" .. tostring(c) .. ")")
end
no('{"code":400}', "json code 400")
no('{"error":{"code":400}}', "error.code 400")
no("code:400", "code:400")
no("HTTP 400", "HTTP 400")
no("status: 400", "status: 400")
yes('{"code":503}', "code 503")
yes('{"code":429}', "code 429")
local r, c = el.should_retry("Sem resposta", "")
T(r == true and c == nil, "sem código repete")
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
