package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local f = require("ui.format_num").formatar_limite
local cases = {
  {1000000, "1m"},
  {1500000, "1.5m"},
  {128000, "128k"},
  {999999, "999999"},
  {1000, "1k"},
  {500, "500"},
  {2000000, "2m"},
}
for _, c in ipairs(cases) do
  local got = f(c[1])
  T(got == c[2], tostring(c[1]) .. " -> " .. c[2] .. " (got " .. tostring(got) .. ")")
end
T(not tostring(f(1000000)):find("%.0"), "sem .0")
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
