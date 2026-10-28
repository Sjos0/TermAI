-- tests/tui_card_bg_spec.lua — Issue #176 P1: cada linha do corpo de card tem fundo c.bg,
-- ocupa no máximo tw-1 colunas e reseta a cor no fim, sem vazar para a linha seguinte.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local function plain(s) return (s:gsub("\27%[[%d;]*m", "")) end
local function width(s) return utf8.len(plain(s)) or #plain(s) end

local card = require("ui.card")
local core = require("ui.core")
local body = require("ui.tools_init.default_body")
local BG = "\27[48;5;234m"

-- 1) bg_row isolado
local row = card.bg_row(BG, "", " │ ", "", "hello", 40)
check(row:sub(1, #BG) == BG, "bg_row começa com o fundo c.bg")
check(row:sub(-4) == "\27[0m", "bg_row termina com reset")
check(width(row) == 39, "bg_row ocupa tw-1 colunas (39 de 40)")

-- 2) corpo real: captura io.write do default_body
local function capture(fn)
  local out, real = {}, io.write
  io.write = function(...) for _, v in ipairs({...}) do out[#out + 1] = tostring(v) end return io.stdout end
  local ok, err = pcall(fn)
  io.write = real
  assert(ok, err)
  return table.concat(out)
end

local tw = 60
local text = capture(function()
  body.render_default_body({ "primeira linha", "segunda", "terceira", "quarta", "quinta", "sexta", "sétima ção" }, tw)
end)
local lines = {}
for ln in text:gmatch("([^\n]*)\n") do lines[#lines + 1] = ln end
check(#lines == 6, "corpo recolhe em 5 linhas + linha de '... (N linhas)'")
local all_bg, all_fit, all_reset = true, true, true
for _, ln in ipairs(lines) do
  if ln:sub(1, #BG) ~= BG then all_bg = false end
  if width(ln) > tw - 1 then all_fit = false end
  if ln:sub(-4) ~= "\27[0m" then all_reset = false end
end
check(all_bg, "toda linha do corpo começa com c.bg")
check(all_fit, "nenhuma linha passa de tw-1 colunas")
check(all_reset, "toda linha termina com reset (sem vazar fundo)")

-- 3) Ctrl+O (expand) também pinta
local exp = capture(function() body.expand() end)
local any_bg = false
for ln in exp:gmatch("([^\n]*)\n") do if ln:sub(1, #BG) == BG then any_bg = true end end
check(any_bg, "expand (Ctrl+O) também usa fundo nas linhas")

-- 4) edit_renderer (diff): todas as linhas com fundo, dentro da largura e com reset
local edit = require("ui.tools_init.edit_renderer")
local elines = { "arquivo.lua", "METRICS: added=1, removed=1", "  10 - |old line", "  10 + |new line", "  11 |ctx" }
local etext = capture(function() edit.render_edit_body(elines, true, tw) end)
local erows = {}
for ln in etext:gmatch("([^\n]*)\n") do erows[#erows + 1] = ln end
check(#erows >= 4, "edit_renderer escreve resumo, diff e rodapé")
local e_bg, e_fit, e_reset = true, true, true
for _, ln in ipairs(erows) do
  if ln:sub(1, #BG) ~= BG then e_bg = false end
  if width(ln) > tw - 1 then e_fit = false end
  if ln:sub(-4) ~= "\27[0m" then e_reset = false end
end
check(e_bg, "edit_renderer: toda linha começa com c.bg")
check(e_fit, "edit_renderer: nenhuma linha passa de tw-1 colunas")
check(e_reset, "edit_renderer: toda linha termina com reset")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
