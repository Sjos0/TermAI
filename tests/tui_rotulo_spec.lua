-- tests/tui_rotulo_spec.lua — Issue #176 P3: rótulo segue o turno, quadros no TMPDIR, spinner sh desenha o brilho.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local function plain(s) return (s:gsub("\27%[[%d;]*m", "")) end

local dir = "/tmp/termai_rotulo_test"
os.execute("rm -rf " .. dir .. " && mkdir -p " .. dir)
os.getenv = (function(orig) return function(k) if k == "TMPDIR" then return dir end return orig(k) end end)(os.getenv)
package.loaded["ui.spinner.rotulo"] = nil
local rot = require("ui.spinner.rotulo")
local real_write = io.write
io.write = function() end -- região: stty não existe em teste; evita ruído

local function primeira_linha(path)
  local f = io.open(path, "r"); if not f then return nil end
  local l = f:read("*l"); f:close(); return l
end
local function existe(path) local f = io.open(path, "r"); if f then f:close() return true end return false end

rot.evento("user_send")
check(primeira_linha(dir .. "/termai_frames.txt") == tostring(#"Injetando" + 6), "user_send: quadros de Injetando no TMPDIR")
rot.evento("inject_done")
check(primeira_linha(dir .. "/termai_frames.txt") == tostring(#"Requisitando" + 6), "inject_done: quadros trocam para Requisitando")
rot.evento("agent_turn")
check(primeira_linha(dir .. "/termai_frames.txt") == tostring(#"Trabalhando" + 6), "agent_turn: quadros trocam para Trabalhando")
rot.evento("agent_turn")
check(rot.estado() == "trabalhando", "agent_turn repetido não reverte nem reinicia")
rot.evento("turn_end")
check(not existe(dir .. "/termai_frames.txt"), "turn_end: quadros apagados (ocioso)")
io.write = real_write

-- spinner sh real: o script embutido precisa desenhar "Trabalhando" com os quadros
io.write = function() end
rot.evento("user_send"); rot.evento("inject_done"); rot.evento("agent_turn")
io.write = real_write
local roteiros = require("ui.spinner.roteiros")
local sh_path = dir .. "/spin.sh"
local f = io.open(sh_path, "w"); f:write(roteiros.SPINNER_SCRIPT); f:close()
os.execute("TMPDIR=" .. dir .. " timeout 1 sh " .. sh_path .. " > " .. dir .. "/out.txt 2>/dev/null")
local g = io.open(dir .. "/out.txt", "r"); local out = g and g:read("*a") or ""; if g then g:close() end
local txt = plain(out)
check(txt:find("Trabalhando", 1, true) ~= nil, "spinner sh: desenha a palavra Trabalhando com brilho")
check(txt:find("Requisitando", 1, true) == nil, "spinner sh: não mostra Requisitando depois do turno do agente")
rot.reset()

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
