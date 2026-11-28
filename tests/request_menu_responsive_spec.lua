package.path = "./?.lua;./?/init.lua;./lib/?.lua;./renderer/?.lua;" .. package.path

local failures = 0
local function T(ok, message)
  if ok then print("PASS " .. message)
  else failures = failures + 1; print("FAIL " .. message) end
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

local function max_width(output)
  local maximum = 0
  for line in (output .. "\n"):gmatch("([^\n]*)\n") do
    maximum = math.max(maximum, largura.colunas(line))
  end
  return maximum
end

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

core.tw = original_tw
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
