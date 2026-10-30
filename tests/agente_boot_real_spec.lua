-- tests/agente_boot_real_spec.lua — #223: carrega agente.lua headless sem crash
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

-- Lint: pcall(...).campo na mesma linha (padrão #191)
local src = assert(io.open("agente.lua", "r")):read("*a")
local bad = nil
for line in (src .. "\n"):gmatch("([^\n]*)\n") do
  if line:match("pcall%s*%b()%.%s*[%w_]+") then bad = line; break end
end
T(bad == nil, "sem pcall(...).campo")

-- Execução real: carregar agente.lua sob stubs de TUI/loop
-- Isola HOME e impede main_loop de bloquear
local real_exit = os.exit
os.exit = function(code) error("__exit__:" .. tostring(code), 0) end

package.loaded["agent.main_loop"] = {
  run = function() end,
}
package.loaded["agent.context"] = {
  build = function() return { msgs = {}, cfg = {} }, nil end,
}
package.loaded["agent.startup"] = {
  run = function() end,
}
package.loaded["ui.spinner"] = {
  cleanup_startup = function() end,
}
package.loaded["ui.terminal_safe"] = {
  install = function() end,
}

-- agente.lua no final tipicamente chama main_loop — stub evita hang
local ok, err = pcall(function()
  -- limpa cache
  package.loaded["agente"] = nil
  dofile("agente.lua")
end)
os.exit = real_exit

if not ok and tostring(err):find("__exit__") then
  ok = true -- saiu via os.exit controlado
end
T(ok == true, "agente.lua carrega sem erro Lua: " .. tostring(err))

-- Prova de que a linha antiga falharia no lint
local old = 'local x = pcall(require, "ui.terminal_safe").install()'
T(old:match("pcall%s*%b()%.%s*[%w_]+") ~= nil, "linha antiga seria detectada pelo lint")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
