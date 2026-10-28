-- tests/tui_hotfix_spec.lua — Hotfix: a região de rolagem fica desligada e nada no fluxo a emite.
-- Estresse: vários ciclos de eventos (turnos seguidos) não podem deixar sequências de posição/região.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local dir = os.getenv("TMPDIR") or "/tmp"

local rot = require("ui.spinner.rotulo")
local captured = {}
local real_write = io.write
io.write = function(...) for _, v in ipairs({...}) do captured[#captured + 1] = tostring(v) end return io.stdout end
for _ = 1, 20 do
  rot.evento("user_send"); rot.evento("inject_done"); rot.evento("agent_turn")
  rot.evento("agent_turn"); rot.evento("turn_end")
end
io.write = real_write
local emitted = table.concat(captured)

check(rot.regiao_ativa() == false, "hotfix: região não fica ativa")
check(emitted:find("\27%[%d*;?%d*[rH]") == nil, "20 turnos seguidos não emitem DECSTBM nem posição absoluta")
check(emitted:find("\27" .. "7", 1, true) == nil, "20 turnos seguidos não emitem ESC 7")
check(rot.estado() == "idle", "estado volta a ocioso no fim de cada turno")

-- o spinner continua escrevendo só com \r mesmo que alguém deixe um arquivo de altura para trás
local roteiros = require("ui.spinner.roteiros")
local sh_path = dir .. "/tui_hotfix_spin.sh"
local f = io.open(sh_path, "w"); f:write(roteiros.SPINNER_SCRIPT); f:close()
f = io.open(dir .. "/termai_rows.txt", "w"); f:write("30"); f:close()
f = io.open(dir .. "/termai_frames.txt", "w"); f:write("2\nXY\nZW\n"); f:close()
os.execute("TMPDIR=" .. dir .. " timeout 1 sh " .. sh_path .. " > " .. dir .. "/hot_out.bin 2>/dev/null")
local g = io.open(dir .. "/hot_out.bin", "rb"); local out = g and g:read("*a") or ""; if g then g:close() end
check(out:find("\27%[30;1H") == nil, "arquivo de altura velho é ignorado (sem ESC[30;1H)")
check(out:find("\r", 1, true) ~= nil, "spinner escreve com \\r na linha atual")

-- o rótulo passa por Trabalhando, nunca volta a Requisitando dentro do turno
rot.evento("user_send"); rot.evento("inject_done"); rot.evento("agent_turn")
local f2 = io.open(dir .. "/termai_frames.txt", "r"); local first = f2 and f2:read("*l") or ""; if f2 then f2:close() end
check(first == tostring(#"Trabalhando" + 6), "quadros do turno são de Trabalhando")
rot.evento("turn_end")

os.remove(sh_path); os.remove(dir .. "/hot_out.bin"); os.remove(dir .. "/termai_rows.txt"); os.remove(dir .. "/termai_frames.txt")
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
