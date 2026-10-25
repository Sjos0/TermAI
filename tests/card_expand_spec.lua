-- tests/card_expand_spec.lua — Ctrl+O: expande o corpo do último card, sem recolher e sem quebrar a largura.
package.path = "./?.lua;./?/init.lua;" .. package.path

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local function capture(fn)
  local buf, orig = {}, io.write
  io.write = function(...) for _, v in ipairs({ ... }) do buf[#buf + 1] = tostring(v) end end
  local ok, err = pcall(fn)
  io.write = orig
  assert(ok, err)
  return (table.concat(buf):gsub("\27%[[%d;]*[A-Za-z]", ""))
end

local core = require("ui.core")
local body = require("ui.tools_init.default_body")
local card = require("ui.card")
core.tw = function() return 40 end

local lines = {}
for i = 1, 12 do lines[i] = "linha número " .. i .. " com acentuação ção" end

-- (1) Recolhido por padrão: 5 linhas + a linha de quantas faltam.
local collapsed = capture(function() body.render_default_body(lines, 40) end)
check(collapsed:find("... (7 linhas)", 1, true) ~= nil, "recolhido: mostra quantas linhas faltam")
check(collapsed:find("linha número 12", 1, true) == nil, "recolhido: não mostra a última linha")

-- (2) Ctrl+O: expande o último card com todas as linhas.
local expanded = capture(function() assert(body.expand()) end)
check(expanded:find("linha número 12", 1, true) ~= nil, "Ctrl+O: mostra a última linha do card")
check(expanded:find("... (", 1, true) == nil, "Ctrl+O: não recolhe de novo")
local widest = 0
for line in (expanded .. "\n"):gmatch("([^\n]*)\n") do
  local w = utf8.len(line) or #line
  if w > widest then widest = w end
end
check(widest <= 40, "Ctrl+O: nenhuma linha passa da largura da tela (" .. widest .. ")")

-- (3) Ctrl+O sem nenhum card ainda: não faz nada (retorna false).
package.loaded["ui.tools_init.default_body"] = nil
local fresh = require("ui.tools_init.default_body")
check(fresh.expand() == false, "Ctrl+O sem card: não escreve nada")

-- (4) O leitor de teclas tem o ramo de Ctrl+O (código 15) e chama a expansão.
local src = require("tests.helpers.fonte").ler("ui/input")
check(src:find("code == 15", 1, true) ~= nil and src:find("default_body\").expand()", 1, true) ~= nil,
  "leitor de teclas: Ctrl+O chama a expansão do último card")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
