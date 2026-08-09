-- tests/permissions_ui_modal_spec.lua — Lifecycle alternate screen (PR #24 v5)
package.path = "./?.lua;./?/init.lua;" .. package.path

local pass, fail = 0, 0
local function T(name, ok, detail)
  if ok then
    pass = pass + 1
    print("  ✅ " .. name)
  else
    fail = fail + 1
    print("  ❌ " .. name .. (detail and (" — " .. detail) or ""))
  end
end

local function sec(title)
  print("\n=== " .. title .. " ===")
end

local captured = {}
local read_queue = {}
local orig_write, orig_read, orig_flush

local function install_io_mocks()
  captured = {}
  orig_write = io.write
  orig_read  = io.read
  orig_flush = io.flush
  io.write = function(...)
    local n = select("#", ...)
    local parts = {}
    for i = 1, n do parts[i] = tostring(select(i, ...)) end
    captured[#captured + 1] = table.concat(parts)
    return true
  end
  io.read = function()
    if #read_queue == 0 then return "c" end
    return table.remove(read_queue, 1)
  end
  io.flush = function() return true end
end

local function restore_io()
  io.write = orig_write
  io.read  = orig_read
  io.flush = orig_flush
end

local function all_output()
  return table.concat(captured)
end

local function count_occ(s, pat)
  local n = 0
  for _ in s:gmatch(pat) do n = n + 1 end
  return n
end

local ui = require("tools.exec.permissions_ui")

sec("1. Lifecycle alternate screen")

install_io_mocks()
ui._enter_modal_screen()
local out1 = all_output()
T("enter emite ESC[?1049h", out1:find("\27%[?1049h", 1, false) ~= nil)
T("enter emite clear+home ESC[2J ESC[H", out1:find("\27%[2J", 1, false) ~= nil and out1:find("\27%[H", 1, false) ~= nil)
T("enter NÃO usa ESC[1A", not out1:find("\27%[1A", 1, false))
T("enter NÃO usa ESC[2K", not out1:find("\27%[2K", 1, false))
restore_io()

install_io_mocks()
ui._leave_modal_screen()
local out2 = all_output()
T("leave emite ESC[?1049l", out2:find("\27%[?1049l", 1, false) ~= nil)
T("leave emite reset ESC[0m", out2:find("\27%[0m", 1, false) ~= nil)
T("leave NÃO usa ESC[1A", not out2:find("\27%[1A", 1, false))
T("leave NÃO usa ESC[2K", not out2:find("\27%[2K", 1, false))
restore_io()

sec("2. Resultados de escolha (show_dialog)")

local cases = {
  { input = "1", expect = "once",  label = "Permitido uma vez" },
  { input = "",  expect = "once",  label = "Permitido uma vez" },
  { input = "2", expect = "always", label = "Permitido sempre" },
  { input = "3", expect = "deny",  label = "Negado" },
  { input = "4", expect = "block", label = "Bloqueado permanentemente" },
  { input = "c", expect = "cancel", label = "Cancelado" },
}

for _, case in ipairs(cases) do
  install_io_mocks()
  read_queue = { case.input }
  local decision = ui.show_dialog("Exec", "echo hello", nil, nil, false)
  local out = all_output()
  local tag = case.input == "" and "<Enter>" or case.input
  T("choice '" .. tag .. "' → " .. case.expect, decision == case.expect)
  T("choice '" .. tag .. "' emite enter+leave",
    out:find("\27%[?1049h", 1, false) ~= nil and out:find("\27%[?1049l", 1, false) ~= nil)
  T("choice '" .. tag .. "' status na main: " .. case.label,
    out:find(case.label, 1, true) ~= nil)
  local leave_pos = out:find("\27%[?1049l", 1, false)
  local label_pos = out:find(case.label, 1, true)
  T("choice '" .. tag .. "' leave antes do status",
    leave_pos ~= nil and label_pos ~= nil and leave_pos < label_pos)
  T("choice '" .. tag .. "' sem ESC[1A collapse", not out:find("\27%[1A", 1, false))
  T("choice '" .. tag .. "' sem ESC[2K collapse", not out:find("\27%[2K", 1, false))
  restore_io()
end

sec("3. Cleanup em erro (xpcall)")

install_io_mocks()
io.read = function()
  error("simulated dialog failure", 0)
end
local ok_call = pcall(function()
  ui.show_dialog("Exec", "rm -rf /tmp/x", nil, { { message = "rm -rf" } }, false)
end)
local out_err = all_output()
T("erro propaga (pcall falha)", ok_call == false)
T("mesmo com erro, leave ESC[?1049l foi emitido", out_err:find("\27%[?1049l", 1, false) ~= nil)
T("mesmo com erro, enter ESC[?1049h foi emitido", out_err:find("\27%[?1049h", 1, false) ~= nil)
T("erro: leave ocorre exatamente 1 vez", count_occ(out_err, "\27%[?1049l") == 1)
restore_io()

sec("4. Retry após entrada inválida")

install_io_mocks()
read_queue = { "x", "1" }
local d4 = ui.show_dialog("Read", "/tmp/file", nil, nil, false)
local out4 = all_output()
T("após 'x' inválido, '1' → once", d4 == "once")
T("mensagem de entrada inválida presente", out4:find("Entrada inválida", 1, true) ~= nil)
T("retry ainda faz enter+leave uma vez cada",
  count_occ(out4, "\27%[?1049h") == 1 and count_occ(out4, "\27%[?1049l") == 1)
restore_io()

sec("5. Mecanismo antigo ausente")

install_io_mocks()
read_queue = { "1" }
ui.show_dialog("Exec", "curl -L https://example.com/a.pdf && curl -L https://example.com/b.pdf", nil, {
  { message = "Operador lógico '&&' detectado" },
}, true)
local out5 = all_output()
T("fluxo longo sem ESC[1A", not out5:find("\27%[1A", 1, false))
T("fluxo longo sem ESC[2K", not out5:find("\27%[2K", 1, false))
T("fluxo longo usa alternate screen", out5:find("\27%[?1049h", 1, false) ~= nil)
T("status final na main", out5:find("Permitido uma vez", 1, true) ~= nil)
restore_io()

print("\n" .. string.rep("═", 60))
print(string.format("PERMISSIONS UI MODAL: %d passaram, %d falharam", pass, fail))
print(string.rep("═", 60))
if fail > 0 then os.exit(1) end
