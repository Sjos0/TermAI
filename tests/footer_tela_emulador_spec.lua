-- tests/footer_tela_emulador_spec.lua — #253/#265: rodapé real, emulador SEM strip prévio.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local function ref_w(s)
  s = tostring(s or "")
  local n, i = 0, 1
  while i <= #s do
    local csi = s:match("^\27%[[0-9;:?]*[A-Za-z]", i)
    if csi then
      i = i + #csi
    else
      local p = utf8.offset(s, 2, i)
      local last = p and (p - 1) or #s
      local ok, cp = pcall(utf8.codepoint, s, i, last)
      if ok and cp then
        if cp == 0xFE0F or cp == 0x200D then
        elseif cp >= 0x1F300 and cp <= 0x1FAFF then n = n + 2
        elseif cp == 0x2705 or cp == 0x274C then n = n + 2
        elseif cp >= 0x3000 and cp <= 0x9FFF then n = n + 2
        elseif cp >= 32 then n = n + 1 end
      end
      i = last + 1
    end
  end
  return n
end

local core = require("ui.core")
local misc = require("ui.misc")

local function capture(tw, a, b, elapsed, clock)
  core.invalidate_size()
  local orig = core.tw
  core.tw = function() return tw end
  local buf, real = {}, io.write
  io.write = function(...) for _, v in ipairs({ ... }) do buf[#buf + 1] = tostring(v) end end
  misc.footer(a, b, elapsed, clock)
  io.write = real
  core.tw = orig
  core.invalidate_size()
  return table.concat(buf)
end

local function lines_of(out)
  local t = {}
  for ln in (out .. "\n"):gmatch("([^\n]*)\n") do t[#t + 1] = ln end
  while #t > 0 and t[#t] == "" do t[#t] = nil end
  return t
end

for _, tw in ipairs({ 40, 80, 120 }) do
  local out = capture(tw, 43317, 1000000, 8700, "14:05")
  local ls = lines_of(out)
  T(#ls == 3, "T1 tw=" .. tw .. " 3 linhas (got " .. #ls .. ")")
  T(ref_w(ls[1]) == tw, "T1 tw=" .. tw .. " topo ref_w=" .. ref_w(ls[1] or ""))
  T(ref_w(ls[2]) == tw, "T1 tw=" .. tw .. " corpo ref_w=" .. ref_w(ls[2] or ""))
  T(ref_w(ls[3]) == tw, "T1 tw=" .. tw .. " base ref_w=" .. ref_w(ls[3] or ""))
  local plain_end = (ls[2] or ""):gsub("\27%[[0-9;:?]*[A-Za-z]", "")
  T(plain_end:find("│", 1, true) ~= nil, "T1 tw=" .. tw .. " borda direita presente")
end

do
  local out = capture(80, 100, 128000, nil, "14:05")
  local ls = lines_of(out)
  T(#ls == 3, "T2 3 linhas")
  T(ref_w(ls[2]) == 80, "T2 corpo largura 80")
  T((ls[2] or ""):find("14:05", 1, true), "T2 tem relogio")
end

T(not capture(15, 1, 10, nil, nil):find("┌", 1, true), "T3 sem moldura")

do
  local out = capture(80, 43317, 1000000, 8700, "14:05")
  T(out:find("43317", 1, true) and out:find("1m", 1, true), "T4 tokens completos em tw=80")
  T(out:find("8.7", 1, true) and out:find("14:05", 1, true), "T4 tempo e relogio presentes")
end

T(ref_w(lines_of(capture(40, 1, 100, nil, "漢"))[2] or "") == 40, "T5 CJK corpo 40")

do
  local a = ref_w(lines_of(capture(80, 1, 100, 100, "12:00"))[1])
  local b = ref_w(lines_of(capture(40, 1, 100, 100, "12:00"))[1])
  T(a == 80 and b == 40, "T6 responsivo")
end

do
  local top = (lines_of(capture(80, 1, 100, nil, nil))[1] or ""):gsub("\27%[[0-9;:?]*[A-Za-z]", "")
  T(not top:match("[A-Za-z]"), "T7 topo so borda")
end

do
  local out = capture(40, 43317, 1000000, 8700, "14:05")
  T(out:find("43317", 1, true) and out:find("1m", 1, true), "prioridade: tokens intactos em tw=40")
end

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
