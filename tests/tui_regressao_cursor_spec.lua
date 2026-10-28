-- tests/tui_regressao_cursor_spec.lua — Regressão (v1.31 no Moto): \0337 no printf virava octal 337
-- (animação travava e subia) e DECSTBM sem salvar cursor sobrescrevia o topo da tela.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local dir = os.getenv("TMPDIR") or "/tmp"
local function read_all(p) local f = io.open(p, "rb"); if not f then return "" end local s = f:read("*a"); f:close(); return s end

local roteiros = require("ui.spinner.roteiros")
local sh_path = dir .. "/tui_regr_cursor.sh"
local f = io.open(sh_path, "w"); f:write(roteiros.SPINNER_SCRIPT); f:close()
local fq = io.open(dir .. "/termai_frames.txt", "w"); fq:write("2\nAB\nCD\n"); fq:close()
local fr = io.open(dir .. "/termai_rows.txt", "w"); fr:write("24"); fr:close()
os.execute("TMPDIR=" .. dir .. " timeout 1 sh " .. sh_path .. " > " .. dir .. "/regr_out.bin 2>/dev/null")
local out = read_all(dir .. "/regr_out.bin")
check(out:find("\27" .. "7\27[24;1H", 1, true) ~= nil, "spinner: salva o cursor e vai para a última linha com ESC real")
check(out:find("\27" .. "8", 1, true) ~= nil, "spinner: restaura o cursor com ESC real")
check(out:find(string.char(0xDF), 1, true) == nil, "spinner: não escreve o octal 337 (byte 0xDF) no lugar do ESC")

os.remove(sh_path); os.remove(dir .. "/termai_frames.txt"); os.remove(dir .. "/termai_rows.txt"); os.remove(dir .. "/regr_out.bin")
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
