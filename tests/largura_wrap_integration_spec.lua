-- Integração da API de wrapping compartilhada entre menu de Requisições e API Keys.
-- Em branches isoladas, valida os consumidores presentes; na árvore combinada,
-- ambos os caminhos são carregados e exercitados no mesmo processo.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;./renderer/?.lua;" .. package.path

local failures = 0
local function T(ok, message)
  if ok then print("PASS " .. message)
  else failures = failures + 1; print("FAIL " .. message) end
end

local wrap = require("ui.largura_wrap")
local largura = require("ui.largura")
T(type(wrap) == "table" and type(wrap.quebrar) == "function",
  "shared helper exports the table API")
local function wrap_text(texto, limite)
  return wrap.quebrar(texto, limite, largura.colunas)
end
if type(largura.quebrar) == "function" then
  T(true, "ui.largura exposes the shared wrapping API")
  local delegated = largura.quebrar("delegação visual", 8)
  T(type(delegated) == "table" and #delegated > 1,
    "ui.largura delegates to the shared helper")
else
  print("SKIP ui.largura wrapper integration: PR #378 consumer not present in this branch")
end

local sample = "texto UTF-8 com acentuação e caracteres 界界 para validar wrapping responsivo sem perda"
for _, width in ipairs({20, 31, 40, 50, 80}) do
  local lines = wrap_text(sample, width - 5)
  local fits, reconstructed = true, table.concat(lines, " ")
  for _, line in ipairs(lines) do
    if largura.colunas(line) > width - 5 then fits = false end
  end
  T(fits, "shared API respects " .. width .. " columns")
  T(reconstructed == sample, "shared API preserves UTF-8 content at " .. width)
end

local ansi = "\27[38;5;80m" .. string.rep("x", 35) .. "\27[0m"
local ansi_lines = wrap_text(ansi, 10)
local ansi_fits, ansi_kept = true, table.concat(ansi_lines)
for _, line in ipairs(ansi_lines) do
  if largura.colunas(line) > 10 then ansi_fits = false end
end
T(ansi_fits and #ansi_lines > 1, "SGR sequences do not count as visible columns")
T(ansi_kept == ansi, "SGR sequences and visible content are preserved")

local wide = "界界界界界界"
local wide_lines = wrap_text(wide, 4)
local wide_fits = true
for _, line in ipairs(wide_lines) do
  if largura.colunas(line) > 4 then wide_fits = false end
end
T(wide_fits and table.concat(wide_lines) == wide,
  "double-width characters wrap without loss")

local long_word = string.rep("Z", 53)
local word_lines = wrap_text(long_word, 9)
local word_fits = true
for _, line in ipairs(word_lines) do
  if largura.colunas(line) > 9 then word_fits = false end
end
T(word_fits and table.concat(word_lines) == long_word,
  "unbroken long values are split without truncation")

-- Stub apenas do terminal e de dependências de entrada; os renderizadores
-- reais dos menus continuam sendo chamados e escrevem pela io.write real capturada.
local terminal_width = 80
local core = {
  tw = function() return terminal_width end,
  regua = function(maximo, usado) return string.rep("─", math.max(0, math.min(maximo, terminal_width - (usado or 2)))) end,
}
package.loaded["ui.core"] = core
package.loaded["commands.models.ui"] = {
  c = { reset = "\27[0m", bold = "\27[1m", dim = "\27[2m", gray = "\27[90m",
    white = "", green = "", yellow = "", red = "", cyan = "\27[36m" },
  header = function() end,
  hdr = function() end,
}
package.loaded.config = { load = function() return {} end }
package.loaded["agent.api"] = {
  CURL_TIMEOUT = 180, MAX_RETRIES = 10, RETRY_MODE = "exponential",
  RETRY_STATIC = 5, RETRY_MAX = 30,
}
package.loaded["commands.config.menus.request.saver"] = { save_req = function() end }
package.loaded["commands.config.menus.request.fallback.models"] = function() end
package.loaded["commands.config_cli.menus.request.fallback.models"] = function() end

local function capture(fn)
  local chunks, original = {}, io.write
  io.write = function(...)
    for i = 1, select("#", ...) do chunks[#chunks + 1] = tostring(select(i, ...)) end
  end
  local ok, err = xpcall(fn, debug.traceback)
  io.write = original
  if not ok then return nil, err end
  return table.concat(chunks)
end

local function output_fits(output, width)
  if not output then return false end
  for line in output:gmatch("([^\n]+)") do
    if largura.colunas(line) > width then return false end
  end
  return true
end

-- PR #377: os métodos públicos exercitam o renderer CLI/TUI real da lista de keys.
local cli_keys_ok, cli_keys = pcall(require, "commands.config_cli.menus.request.fallback")
local tui_keys_ok, tui_keys = pcall(require, "commands.config.menus.request.fallback")
if cli_keys_ok and type(cli_keys.render_health_rows) == "function"
    and tui_keys_ok and type(tui_keys.render_health_rows) == "function" then
  local masked = "****" .. string.rep("K", 24) .. "mnop"
  local last = "[última falha: 2026-11-28T07:41:00.123456789Z motivo=timeout_"
    .. string.rep("X", 42) .. " recurso=界界界]"
  local row = { { index = 1, masked = masked, state = "\27[31mFALHA\27[0m",
    active = true, last = last } }
  for _, width in ipairs({20, 31, 40, 50, 80}) do
    terminal_width = width
    local cli_out = capture(function() cli_keys.render_health_rows(row) end)
    local tui_out = capture(function() tui_keys.render_health_rows(row) end)
    T(output_fits(cli_out, width), "all real API Keys CLI lines fit " .. width)
    T(output_fits(tui_out, width), "all real API Keys TUI lines fit " .. width)
    local expected_identity = ("1." .. masked .. "FALHA[ATIVA]")
    local expected_last = largura.visivel(last):gsub("%s+", "")
    local function normalized(output)
      return largura.visivel(output or ""):gsub("%s+", "")
    end
    T(normalized(cli_out):find(expected_identity, 1, true) ~= nil,
      "real API Keys CLI preserves long identity, state and active marker at " .. width)
    T(normalized(tui_out):find(expected_identity, 1, true) ~= nil,
      "real API Keys TUI preserves long identity, state and active marker at " .. width)
    T(normalized(cli_out):find(expected_last, 1, true) ~= nil,
      "real API Keys CLI preserves full failure metadata at " .. width)
    T(normalized(tui_out):find(expected_last, 1, true) ~= nil,
      "real API Keys TUI preserves full failure metadata at " .. width)
    local function continuations_indented(output)
      local count = 0
      for line in (output or ""):gmatch("([^\n]+)") do
        if line:sub(1, 5) == "     " then count = count + 1 end
        if line:sub(1, 2) ~= "  " then return false end
      end
      return count >= 2
    end
    T(continuations_indented(cli_out), "real API Keys CLI keeps continuation indentation at " .. width)
    T(continuations_indented(tui_out), "real API Keys TUI keeps continuation indentation at " .. width)
  end
else
  print("SKIP API Keys renderer integration: PR #377 consumer not present in this branch")
end

-- PR #378: exercita row/option e o status/opções dos renderizadores reais CLI/TUI.
local cli_utils_ok, cli_utils = pcall(require, "commands.config_cli.ui_utils")
local tui_view_ok, tui_view = pcall(require, "commands.config.menus.request.view")
local cli_source = assert(io.open("commands/config_cli/ui_utils.lua", "r")):read("*a")
local tui_source = assert(io.open("commands/config/menus/request/view.lua", "r")):read("*a")
local responsive_cli = cli_source:find("largura.quebrar", 1, true) ~= nil
local responsive_tui = tui_source:find("largura.quebrar", 1, true) ~= nil
if cli_utils_ok and responsive_cli and tui_view_ok and responsive_tui then
  for _, width in ipairs({20, 31, 40, 50, 80}) do
    terminal_width = width
    package.loaded["commands.config_cli.menus.request.submenus"] = {}
    local install_request_menu = require("commands.config_cli.menus.request.parte_1")
    local request_menu = {}
    install_request_menu(request_menu)
    local menu_ui = {
      get_cfg = function() return { agents = { defaults = {
        request = { timeout = 180, idle_timeout = 30, max_retries = 10,
          retry_mode = "exponential", retry_static = 5, retry_max = 30,
          wait_timeout = 25, mode = "buffer", reasoning_effort = "medium" },
        thinkingEffort = "high",
      } } } end,
      hdr = function() end,
      SEP2 = function(prefixo) return core.regua(30, largura.colunas(prefixo or "")) end,
      row = cli_utils.row,
      option = cli_utils.option,
      rdl = function() return "0" end,
      cancel = function(value) return not value or value == "" or value == "0" end,
      GR = "", R = "", G = "", DM = "", RE = "", CY = "",
    }
    local cli_out, cli_err = capture(function()
      request_menu.run({ set = function() end }, menu_ui)
    end)
    local tui_out, tui_err = capture(function()
      tui_view.print_status({ timeout = 180, max_retries = 10, retry_mode = "exponential",
        retry_max = 30, wait_timeout = 25, mode = "buffer", reasoning_effort = "medium",
        language = "Português" }, { thinkingEffort = "high" })
      tui_view.print_options()
    end)
    T(output_fits(cli_out, width), "real request-menu CLI renderer fits " .. width)
    T(output_fits(tui_out, width), "real request-menu TUI renderer fits " .. width)
    T(cli_out and cli_out:find("OpenRouter", 1, true) ~= nil,
      "real request-menu CLI renderer preserves label at " .. width)
    T(tui_out and largura.visivel(tui_out):gsub("%s+", ""):find("reasoning_style=openrouter", 1, true) ~= nil,
      "real request-menu TUI renderer preserves description at " .. width)
    if not cli_out then print(cli_err) end
    if not tui_out then print(tui_err) end
  end
else
  print("SKIP request-menu renderer integration: PR #378 consumer not present in this branch")
end

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
