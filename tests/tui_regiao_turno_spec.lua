-- tests/tui_regiao_turno_spec.lua — Issue #176 P3, item 1: o spinner fica vivo no turno inteiro.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local rot     = require("ui.spinner.rotulo")
local compact = require("ui.spinner.compact")
local spinner = require("ui.spinner")

check(rot.regiao_ativa() == false, "sem turno: região não está ativa")
check(compact.is_running() == false, "sem turno: spinner não está rodando")
check(type(spinner.is_running) == "function", "fachada ui.spinner expõe is_running")
check(type(spinner.stop_thinking) == "function", "fachada ui.spinner mantém stop_thinking")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
