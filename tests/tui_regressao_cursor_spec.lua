-- tests/tui_regressao_cursor_spec.lua — Regressão do hotfix: o spinner nunca posiciona o cursor
-- em linha absoluta, nem com um arquivo de altura antigo presente (teclado/rotação quebravam isso).
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local dir = os.getenv("TMPDIR") or "/tmp"
local function read_all(p) local f = io.open(p, "rb"); if not f then return "" end local s = f:read("*a"); f:close(); return s end
local function write_file(p, s) local f = io.open(p, "w"); f:write(s); f:close() end

local roteiros = require("ui.spinner.roteiros")
local sh_path = dir .. "/tui_regr_hotfix.sh"
write_file(sh_path, roteiros.SPINNER_SCRIPT)
write_file(dir .. "/termai_frames.txt", "3\nAB\nCD\nEF\n")
write_file(dir .. "/termai_rows.txt", "24")   -- arquivo velho de altura: não pode ser usado
os.execute("TMPDIR=" .. dir .. " timeout 1 sh " .. sh_path .. " > " .. dir .. "/regr_out.bin 2>/dev/null")
local out = read_all(dir .. "/regr_out.bin")

check(out:find("\27%[%d+;%d+H") == nil, "sem posição absoluta ESC[linha;colH em nenhum quadro")
check(out:find("\27" .. "7", 1, true) == nil and out:find("\27" .. "8", 1, true) == nil, "sem ESC 7 / ESC 8 (cursor não é salvo/restaurado pelo spinner)")
check(out:find("\27%[%d*r") == nil, "sem região de rolagem (DECSTBM) emitida pelo spinner")
local ticks = select(2, out:gsub("\r", ""))
check(ticks >= 3, "animação: vários quadros escritos com \\r na linha atual (" .. ticks .. ")")

os.remove(sh_path); os.remove(dir .. "/termai_frames.txt"); os.remove(dir .. "/termai_rows.txt"); os.remove(dir .. "/regr_out.bin")
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
