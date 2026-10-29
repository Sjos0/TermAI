-- tests/agente_terminal_safe_boot_spec.lua — agente.lua não indexa o boolean do pcall.
-- Regressão: pcall(require, "ui.terminal_safe").install() → attempt to index a boolean.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local src = assert(io.open("agente.lua", "r")):read("*a")

-- Anti-pattern que causou o crash no Termux após v1.35
T(not src:find('pcall%(require,%s*"ui%.terminal_safe"%)%.install'),
  "não indexa pcall(...).install (boolean)")

-- Forma correta: captura ok + módulo
T(src:find("terminal_safe") ~= nil, "referencia terminal_safe")
T(src:find("ok_ts") ~= nil or src:find("local ok") ~= nil, "captura retorno do pcall")

-- Comportamento real: require + install sem crash
local ok, ts = pcall(require, "ui.terminal_safe")
T(ok == true, "require ui.terminal_safe ok")
T(type(ts) == "table" and type(ts.install) == "function", "módulo expõe install()")
if ok and ts and ts.install then
  local ok2 = pcall(ts.install)
  T(ok2 == true, "install() não levanta erro")
end

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
