-- tests/terminal_safe_spec.lua — terminal_safe: os.exit executa stty sane antes
-- de delegar ao original, e encadeia com overrides existentes sem quebrá-los.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local stty_calls = {}
local real_execute = os.execute
os.execute = function(cmd)
  if type(cmd) == "string" and cmd:find("stty sane", 1, true) then
    stty_calls[#stty_calls + 1] = cmd
    return true, "exit", 0
  end
  return real_execute(cmd)
end

-- stub do os.exit nativo para não terminar o processo no teste
local real_exit = os.exit
os.exit = function(...) return "DELEGOU_AO_ORIGINAL" end

local ts = require("ui.terminal_safe")
ts.install()

-- agora os.exit é o override do terminal_safe
local result = os.exit(0)
check(result == "DELEGOU_AO_ORIGINAL", "os.exit delegou ao original após o cleanup")
check(#stty_calls >= 1, "stty sane foi executado na saída do processo")

-- idempotência: instalar de novo não duplica o override
local stty_before = #stty_calls
ts.install()
os.exit(0)
check(#stty_calls == stty_before + 1, "install() é idempotente (não duplica o override)")

os.execute = real_execute
os.exit = real_exit

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
