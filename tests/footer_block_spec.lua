package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local core = require("ui.core")
local misc = require("ui.misc")
local largura = require("ui.largura")
local function vis(s) return largura.colunas((s or ""):gsub("\27%[[0-9;]*m", "")) end

local function capture_footer(tw, a, b, elapsed, clock)
  core.invalidate_size()
  local orig = core.tw
  core.tw = function() return tw end
  local buf, real = {}, io.write
  io.write = function(...) for _, v in ipairs({...}) do buf[#buf+1]=tostring(v) end end
  misc.footer(a, b, elapsed, clock)
  io.write = real
  core.tw = orig
  return table.concat(buf)
end

for _, tw in ipairs({ 40, 80, 120 }) do
  local out = capture_footer(tw, 1000, 1000000, 1500, "14:05")
  local lines = {}
  for ln in (out .. "\n"):gmatch("([^\n]*)\n") do lines[#lines+1] = ln end
  -- 3 block lines + blank
  T(#lines >= 3, "tw=" .. tw .. " pelo menos 3 linhas")
  local l1 = lines[1]:gsub("\27%[[0-9;]*m", "")
  local l3 = lines[3]:gsub("\27%[[0-9;]*m", "")
  T(l1:find("┌", 1, true) and l1:find("┐", 1, true), "tw=" .. tw .. " topo com cantos")
  T(l3:find("└", 1, true) and l3:find("┘", 1, true), "tw=" .. tw .. " base com cantos")
  T(vis(lines[1]) == tw, "tw=" .. tw .. " largura exata linha1 (got " .. vis(lines[1]) .. ")")
end

-- tw < 20: linha simples
do
  local out = capture_footer(15, 10, 100, nil, nil)
  T(not out:find("┌", 1, true), "tw<20 sem moldura")
  T(out:find("tokens:", 1, true), "tw<20 ainda mostra tokens")
end

-- 1m format
do
  local out = capture_footer(80, 1000000, 1000000, nil, nil)
  T(out:find("1m", 1, true), "limite 1m no rodape")
end

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
