-- tests/permissions_ui_modal_spec/01_1_lifecycle_alternate_scre.lua — parte de permissions_ui_modal_spec.lua (ver fachada).
local harness = require("tests.helpers.harness")

local M = {}

function M.run()
  local portable_tmp = require("tests.helpers.tmp")

  local function T(name, ok, detail)
    if ok then
      harness.pass = harness.pass + 1
      print("  ✅ " .. name)
    else
      harness.fail = harness.fail + 1
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
      local v = table.remove(read_queue, 1)
      -- Enter humano leva mais de 0,1 s; o diálogo ignora "" instantâneo (\n residual).
      if v == "" then os.execute("sleep 0.2") end
      return v
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

  -- Contagem por substring literal (plain), sem padrões Lua.
  local function count_occ(s, lit)
    local n, pos = 0, 1
    while true do
      local i = s:find(lit, pos, true)
      if not i then break end
      n = n + 1
      pos = i + #lit
    end
    return n
  end

  local ui = require("tools.exec.permissions_ui")


  sec("1. Lifecycle alternate screen")

  install_io_mocks()
  ui._enter_modal_screen()
  local out1 = all_output()
  T("enter emite ESC[?1049h", out1:find("\27[?1049h", 1, true) ~= nil)
  T("enter emite clear+home ESC[2J ESC[H", out1:find("\27[2J", 1, true) ~= nil and out1:find("\27[H", 1, true) ~= nil)
  T("enter NÃO usa ESC[1A", not out1:find("\27[1A", 1, true))
  T("enter NÃO usa ESC[2K", not out1:find("\27[2K", 1, true))
  restore_io()

  install_io_mocks()
  ui._leave_modal_screen()
  local out2 = all_output()
  T("leave emite ESC[?1049l", out2:find("\27[?1049l", 1, true) ~= nil)
  T("leave emite reset ESC[0m", out2:find("\27[0m", 1, true) ~= nil)
  T("leave NÃO usa ESC[1A", not out2:find("\27[1A", 1, true))
  T("leave NÃO usa ESC[2K", not out2:find("\27[2K", 1, true))
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
      out:find("\27[?1049h", 1, true) ~= nil and out:find("\27[?1049l", 1, true) ~= nil)
    T("choice '" .. tag .. "' status na main: " .. case.label,
      out:find(case.label, 1, true) ~= nil)
    local leave_pos = out:find("\27[?1049l", 1, true)
    local label_pos = out:find(case.label, 1, true)
    T("choice '" .. tag .. "' leave antes do status",
      leave_pos ~= nil and label_pos ~= nil and leave_pos < label_pos)
    T("choice '" .. tag .. "' sem ESC[1A collapse", not out:find("\27[1A", 1, true))
    T("choice '" .. tag .. "' sem ESC[2K collapse", not out:find("\27[2K", 1, true))
    restore_io()
  end

end

return M
