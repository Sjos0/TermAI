-- tests/agente_boot_spec.lua — #206: boot de agente.lua sem indexar boolean do pcall.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local src = assert(io.open("agente.lua", "r")):read("*a")

local bad_line = nil
for line in (src .. "\n"):gmatch("([^\n]*)\n") do
  if line:match("pcall%s*%b()%.%s*[%w_]+") then
    bad_line = line
    break
  end
end
T(bad_line == nil, "sem pcall(...).campo na mesma linha")
T(not src:find('pcall%(require,%s*"ui%.terminal_safe"%)%.install'),
  "sem pcall(require).install literal")
T(src:find("terminal_safe") ~= nil, "referencia terminal_safe")
T(src:find("ok_ts") ~= nil or src:find("local ok") ~= nil, "captura ok do pcall")

local ok, ts = pcall(require, "ui.terminal_safe")
T(ok and type(ts) == "table" and type(ts.install) == "function", "terminal_safe.install existe")
if ok and ts then T(pcall(ts.install), "install() headless ok") end

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
