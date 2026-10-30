package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local function ref_w(s)
  s = (s or ""):gsub("\27%[[0-9;]*m", "")
  local n = 0
  pcall(function()
    for _, cp in utf8.codes(s) do
      if cp == 0xFE0F or cp == 0x200D then
      elseif cp >= 0x1F300 and cp <= 0x1FAFF then n = n + 2
      elseif cp == 0x2705 or cp == 0x274C then n = n + 2
      elseif (cp >= 0x3000 and cp <= 0x9FFF) then n = n + 2
      elseif cp >= 32 then n = n + 1 end
    end
  end)
  return n
end
local core = require("ui.core")
local misc = require("ui.misc")
local function capture(tw, a, b, elapsed, clock)
  core.invalidate_size()
  local orig = core.tw
  core.tw = function() return tw end
  local buf, real = {}, io.write
  io.write = function(...) for _, v in ipairs({...}) do buf[#buf+1]=tostring(v) end end
  misc.footer(a, b, elapsed, clock)
  io.write = real
  core.tw = orig
  core.invalidate_size()
  return table.concat(buf)
end
local function lines_of(out)
  local t = {}
  for ln in (out .. "\n"):gmatch("([^\n]*)\n") do t[#t+1] = ln end
  while #t > 0 and t[#t] == "" do t[#t] = nil end
  return t
end
for _, tw in ipairs({ 40, 80, 120 }) do
  local out = capture(tw, 100, 128000, 2000, "14:05")
  local ls = lines_of(out)
  T(#ls == 3, "T1 tw=" .. tw .. " 3 linhas")
  T(ref_w(ls[1]) == tw, "T1 tw=" .. tw .. " largura")
end
T(not capture(15,1,10,nil,nil):find("┌",1,true), "T3 sem moldura")
T(capture(80,999999,1000000,nil,nil):find("1m",1,true), "T4 1m")
T(ref_w(lines_of(capture(40,1,100,nil,"漢"))[1]) == 40, "T5 CJK")
T(ref_w(lines_of(capture(80,1,100,100,"12:00"))[1]) == 80, "T6")
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
