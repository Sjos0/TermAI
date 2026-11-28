-- tests/request_menu_responsive_spec.lua
-- Regressão Issue #375 / PR #378: menu de Requisições respeita largura do terminal.
--
-- "E se isso mudar?": se row/option voltarem a %-22s fixo, se quebrar parar de
-- dividir palavras longas, se ANSI passar a contar como coluna, ou se a descrição
-- deixar de ir para linha indentada, este spec grita antes de chegar ao Termux.

package.path = "./?.lua;./?/init.lua;./lib/?.lua;./renderer/?.lua;" .. package.path

local failures = 0
local function T(ok, message)
  if ok then
    print("PASS " .. message)
  else
    failures = failures + 1
    print("FAIL " .. message)
  end
end

local core = require("ui.core")
local largura = require("ui.largura")
local original_tw = core.tw

local function capture(fn)
  local output, original = {}, io.write
  io.write = function(...)
    for _, value in ipairs({...}) do output[#output + 1] = tostring(value) end
  end
  local ok, err = pcall(fn)
  io.write = original
  assert(ok, err)
  return table.concat(output)
end

local function lines_of(output)
  local result = {}
  for line in (output .. "\n"):gmatch("([^\n]*)\n") do
    result[#result + 1] = line
  end
  return result
end

local function max_width(output)
  local maximum = 0
  for _, line in ipairs(lines_of(output)) do
    maximum = math.max(maximum, largura.colunas(line))
  end
  return maximum
end

-- ---------------------------------------------------------------------------
-- A) Primária: largura.quebrar
-- ---------------------------------------------------------------------------
local sample = "descrição longa com acentuação e texto Unicode 界 para caber no terminal sem perder nenhuma informação visual importante"
for _, width in ipairs({40, 50, 80}) do
  core.tw = function() return width end
  local lines = largura.quebrar(sample, width - 6)
  T(#lines > 1, "wraps long text at " .. width .. " columns")
  T(table.concat(lines, " "):find("descrição", 1, true) ~= nil,
    "preserves UTF-8 text at " .. width .. " columns")
  for _, line in ipairs(lines) do
    T(largura.colunas(line) <= width - 6, "wrapped line fits at " .. width)
  end
end

-- Palavra ininterrupta maior que o limite deve ser fatiada (sem truncar).
do
  local long_word = string.rep("x", 47)
  local parts = largura.quebrar(long_word, 10)
  T(#parts >= 4, "splits unbroken long word into multiple parts")
  T(table.concat(parts) == long_word, "concat of parts reconstitutes original word")
  for _, p in ipairs(parts) do
    T(largura.colunas(p) <= 10, "each split part fits max width")
  end
end

-- ANSI/SGR não conta como coluna; o texto visível quebra pelo peso real.
do
  local colored = "\27[38;5;80m" .. string.rep("a", 30) .. "\27[0m"
  local parts = largura.quebrar(colored, 10)
  T(#parts >= 3, "ANSI-wrapped text still breaks by visible columns")
  for _, p in ipairs(parts) do
    T(largura.colunas(p) <= 10, "ANSI sequence does not inflate column count")
  end
  T(table.concat(parts):find("\27%[38;5;80m", 1, false) ~= nil, "preserves opening SGR in wrapped output")
end

-- Entradas de borda
do
  T(#largura.quebrar("", 20) == 0 or (#largura.quebrar("", 20) == 1 and largura.quebrar("", 20)[1] == ""),
    "empty string yields empty or single empty line")
  local one = largura.quebrar("ok", 1)
  T(#one >= 1 and largura.colunas(one[1]) <= 1, "max=1 still produces bounded parts")
  local nil_safe = largura.quebrar(nil, 12)
  T(type(nil_safe) == "table", "nil input does not throw")
end

-- ---------------------------------------------------------------------------
-- B) CLI + TUI: status e opções cabem em 40/50/80
-- ---------------------------------------------------------------------------
package.loaded.config = { load = function() return {} end }
local cli = require("commands.config_cli.ui_utils")
local view = require("commands.config.menus.request.view")

for _, width in ipairs({40, 50, 80}) do
  core.tw = function() return width end
  local cli_output = capture(function()
    cli.row("Reasoning Effort (OpenRouter):", "\27[38;5;80mmedium\27[0m  (6 níveis — só afeta modelos com reasoning_style=openrouter)")
    cli.option("8", "Reasoning Effort (OpenRouter)", "(6 níveis — só afeta modelos com reasoning_style=openrouter)")
  end)
  T(max_width(cli_output) <= width, "CLI rows/options fit " .. width .. " columns")

  local tui_output = capture(function()
    view.print_status({
      timeout = 180, max_retries = 10, retry_mode = "exponential",
      retry_max = 30, wait_timeout = 25, mode = "buffer",
      reasoning_effort = "medium",
      language = "Português",
    }, { thinkingEffort = "high" })
    view.print_options()
  end)
  T(max_width(tui_output) <= width, "TUI status/options fit " .. width .. " columns")
  T(tui_output:find("reasoning_style=openrouter", 1, true) ~= nil,
    "TUI keeps full option description at " .. width .. " columns")
end

-- ---------------------------------------------------------------------------
-- C) Hierarquia visual: descrição de opção em linha indentada (não inline truncada)
-- ---------------------------------------------------------------------------
do
  core.tw = function() return 40 end
  local out = capture(function()
    cli.option("9", "Modo de Requisicao", "(stream / buffer — stream emite tokens em tempo real; buffer é resiliente a rede)")
  end)
  local ls = lines_of(out)
  local has_indented_desc = false
  for _, line in ipairs(ls) do
    if line:match("^%s%s%s%s%s%s") and line:find("stream", 1, true) then
      has_indented_desc = true
    end
  end
  T(has_indented_desc, "option description renders on indented secondary line at 40 cols")
  T(max_width(out) <= 40, "option with long description still fits 40 cols")
end

-- row: valor longo vira continuação indentada sob o rótulo
do
  core.tw = function() return 40 end
  local long_val = "valor-extenso-" .. string.rep("bloco-", 12) .. "fim"
  local out = capture(function()
    cli.row("Wait máximo:", long_val)
  end)
  T(max_width(out) <= 40, "long row value wraps within 40 cols")
  T(out:find("Wait máximo", 1, true) ~= nil, "row keeps the label")
  T(out:find("fim", 1, true) ~= nil, "row preserves full value text (no silent truncation)")
end

-- option sem descrição não deve explodir nem imprimir lixo
do
  core.tw = function() return 50 end
  local out = capture(function()
    cli.option("4", "Restaurar padrões", nil)
    cli.option("4b", "Restaurar padrões", "")
  end)
  T(out:find("Restaurar padrões", 1, true) ~= nil, "option without description still prints title")
  T(max_width(out) <= 50, "option without description fits width")
end

core.tw = original_tw
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
