package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- tests/banner_component_spec.lua — Banner reutilizável: a CLI e a TUI têm o mesmo gradiente azul.
package.path = "./?.lua;./?/init.lua;" .. package.path

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local banner = require("ui.banner")
local lines, w = banner.read("assets/banner.txt")
check(lines ~= nil and #lines == 5, "banner tem 5 linhas no assets/banner.txt")
check(w and w >= 20, "largura máxima do banner calculada (" .. tostring(w) .. ")")

-- Gradiente: primeira linha azul claro, última azul escuro (mesma fórmula da TUI).
check(banner.color_for(1, 5) == "\27[38;2;60;180;255m", "gradiente: primeira linha é o azul claro")
check(banner.color_for(5, 5) == "\27[38;2;0;40;150m", "gradiente: última linha é o azul escuro")

-- CLI: a saída renderizada traz as cores do gradiente (antes saía branca, sem cor).
local out = banner.render("assets/banner.txt")
check(out ~= nil and out:find("\27[38;2;60;180;255m", 1, true) ~= nil, "CLI: banner saí com a cor da primeira linha")
check(out:find("\27[38;2;0;40;150m", 1, true) ~= nil, "CLI: banner saí com a cor da última linha")
check(select(2, out:gsub("\n", "")) == 4, "CLI: cinco linhas separadas por quebra")

-- TUI e CLI usam o mesmo componente (não duas cópias da fórmula).
check(io.open("ui/header.lua"):read("*a"):find('require("ui.banner")', 1, true) ~= nil, "TUI usa o componente de banner")
check(io.open("main.lua"):read("*a"):find('require", "ui.banner")', 1, true) ~= nil
      or io.open("main.lua"):read("*a"):find('"ui.banner"', 1, true) ~= nil, "CLI usa o componente de banner")

-- Sem arquivo: nada é escrito (a CLI decide, não quebra).
check(banner.render("assets/nao_existe.txt") == nil, "arquivo ausente: render devolve nil, sem erro")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
