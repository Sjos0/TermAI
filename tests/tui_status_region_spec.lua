-- tests/tui_status_region_spec.lua — Issue #176 P3 (fundação): região de rolagem e brilho do rótulo.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local function plain(s) return (s:gsub("\27%[[%d;]*m", "")) end

local region = require("ui.status_region")
check(region.setup(24) == "\27" .. "7\27[1;23r\27" .. "8", "setup: salva cursor, define faixa até rows-1 e restaura cursor")
check(region.setup(2) == "", "setup: terminal pequeno demais não define faixa")
check(region.teardown(24) == "\27" .. "7\27[24;1H\27[2K\27" .. "8\27" .. "7\27[r\27" .. "8", "teardown: limpa a última linha e solta a faixa sem mover o cursor")
local d = region.draw_status(24, "Trabalhando")
check(d:sub(1, 2) == "\27" .. "7", "draw_status: salva o cursor antes de desenhar")
check(d:sub(-2) == "\27" .. "8", "draw_status: restaura o cursor no fim")
check(d:find("\27[24;1H", 1, true) ~= nil, "draw_status: vai para a última linha")

local shimmer = require("ui.spinner.shimmer")
local frames = shimmer.frames("Trabalhando")
check(#frames == #"Trabalhando" + 6, "shimmer: ciclo tem texto + 2*folga quadros")
local ok_text = true
for _, f in ipairs(frames) do
  if plain(f) ~= "Trabalhando" then ok_text = false end
end
check(ok_text, "shimmer: todo quadro tem o texto na ordem certa")
check(frames[1] ~= frames[4], "shimmer: a faixa de brilho muda de posição entre quadros")
check(frames[1]:find("\27[38;5;", 1, true) ~= nil, "shimmer: usa cores 256 (38;5;N)")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
