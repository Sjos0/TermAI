-- tests/tui_pensou_spec.lua — "Pensando (…)" e "Pensou (…)" continuam como antes, por resposta,
-- mesmo com o spinner vivo no turno (#176 P3, correção).
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local function plain(s) return (s:gsub("\27%[[%d;]*m", "")) end
local function read_all(p) local f = io.open(p, "r"); if not f then return "" end local s = f:read("*a"); f:close(); return s end
local function exists(p) local f = io.open(p, "r"); if f then f:close(); return true end return false end

local dir = os.getenv("TMPDIR") or "/tmp"
local frames = dir .. "/termai_frames.txt"
local reason = dir .. "/ta_reasoning.flag"
local timing = require("ui.spinner.timing")
local compact = require("ui.spinner.compact")
local roteiros = require("ui.spinner.roteiros")
local sh_path = dir .. "/tui_pensou_compact.sh"
local f = io.open(sh_path, "w"); f:write(roteiros.COMPACT_SCRIPT); f:close()

-- 1) sh: com flag de reasoning mostra Pensando; sem flag mostra os quadros de Trabalhando
local fq = io.open(frames, "w"); fq:write("2\nTrabalhando-1\nTrabalhando-2\n"); fq:close()
os.remove(reason)
os.execute("TMPDIR=" .. dir .. " timeout 1 sh " .. sh_path .. " > " .. dir .. "/p1.txt 2>/dev/null")
check(plain(read_all(dir .. "/p1.txt")):find("Trabalhando", 1, true) ~= nil, "sh sem reasoning: mostra os quadros de Trabalhando")
local ff = io.open(reason, "w"); ff:write("1"); ff:close()
os.execute("TMPDIR=" .. dir .. " timeout 1 sh " .. sh_path .. " > " .. dir .. "/p2.txt 2>/dev/null")
check(plain(read_all(dir .. "/p2.txt")):find("Pensando", 1, true) ~= nil, "sh: com reasoning mostra Pensando (…)")
os.remove(reason)

-- 2) Pensou (…) sai só se houve reasoning e zera o estado para a próxima resposta
local captured = {}
local real_write = io.write
io.write = function(...) for _, v in ipairs({...}) do captured[#captured + 1] = tostring(v) end return io.stdout end
compact.finish_reasoning_region()
check(not table.concat(captured):find("Pensou", 1, true), "sem reasoning: não imprime Pensou")
timing.mark_reasoning()
compact.finish_reasoning_region()
io.write = real_write
check(table.concat(captured):find("Pensou ", 1, true) ~= nil, "com reasoning: imprime Pensou (…)")
check(timing.get_reasoning_start_ms() == nil, "depois de Pensou o reasoning é zerado para a próxima resposta")

os.remove(sh_path); os.remove(frames); os.remove(dir .. "/p1.txt"); os.remove(dir .. "/p2.txt")
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
