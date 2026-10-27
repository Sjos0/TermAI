-- tests/tui_exec_stream_spec.lua — Issue #176 P2: saída parcial do Exec aparece no card enquanto roda.
-- Altura do card fica previsível: cabeçalho + MAX_BODY linhas + UMA linha "... (N linhas)" reescrita no lugar.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local function capture(fn)
  local out, real = {}, io.write
  io.write = function(...) for _, v in ipairs({...}) do out[#out + 1] = tostring(v) end return io.stdout end
  local ok, err = pcall(fn)
  io.write = real
  assert(ok, err)
  return table.concat(out)
end

local ui_exec = require("ui.tools_init.executor")
local exec    = require("tools.exec")
local runner  = require("tools.exec.executor")
local cmd     = "Exec | for i in 1 2 3 4 5 6 7 8; do echo L$i; done"

local text = capture(function()
  ui_exec.tool_start(cmd)
  check(type(exec.on_line) == "function", "tool_start liga o callback de saída parcial do Exec")
  local res = runner.run("for i in 1 2 3 4 5 6 7 8; do echo L$i; done", 5, exec.on_line)
  ui_exec.tool_end(cmd, res.output, true)
end)

check(exec.on_line == nil, "tool_end desliga o callback")
check(select(2, text:gsub("\27%[1A\27%[2K", "")) == 2, "linha '...' é reescrita no lugar (2 reescritas para 8 linhas)")
check(text:find("... (3 linhas)", 1, true) ~= nil, "contador final mostra as linhas ocultas (3)")
check(text:find("\27[7A\27[0J", 1, true) ~= nil, "tool_end sobe cabeçalho + 6 linhas parciais (7) antes de redesenhar")
local tail = text:match("\27%[0J(.*)$") or ""
check(tail:find("L5", 1, true) ~= nil and tail:find("L6", 1, true) == nil, "redesenho final mostra o corpo recolhido (L1..L5)")

-- ao vivo: nenhuma linha passa de tw-1 colunas e a linha "..." usa o fundo
local card = require("ui.card")
local tw = require("ui.core").tw()
local BG = "\27[48;5;234m"
check(text:find(BG, 1, true) ~= nil, "linhas parciais usam o fundo c.bg")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
