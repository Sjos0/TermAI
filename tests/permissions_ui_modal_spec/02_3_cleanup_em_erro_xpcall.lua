-- tests/permissions_ui_modal_spec/02_3_cleanup_em_erro_xpcall.lua — parte de permissions_ui_modal_spec.lua (ver fachada).
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
  T("mesmo com erro, leave ESC[?1049l foi emitido", out_err:find("\27[?1049l", 1, true) ~= nil)
  T("mesmo com erro, enter ESC[?1049h foi emitido", out_err:find("\27[?1049h", 1, true) ~= nil)
  T("erro: leave ocorre exatamente 1 vez", count_occ(out_err, "\27[?1049l") == 1)
  restore_io()

  sec("4. Retry após entrada inválida")

  install_io_mocks()
  read_queue = { "x", "1" }
  local d4 = ui.show_dialog("Read", portable_tmp.dir() .. "/file", nil, nil, false)
  local out4 = all_output()
  T("após 'x' inválido, '1' → once", d4 == "once")
  T("mensagem de entrada inválida presente", out4:find("Entrada inválida", 1, true) ~= nil)
  T("retry ainda faz enter+leave uma vez cada",
    count_occ(out4, "\27[?1049h") == 1 and count_occ(out4, "\27[?1049l") == 1)
  restore_io()

  sec("5. Mecanismo antigo ausente")

  install_io_mocks()
  read_queue = { "1" }
  ui.show_dialog("Exec", "curl -L https://example.com/a.pdf && curl -L https://example.com/b.pdf", nil, {
    { message = "Operador lógico '&&' detectado" },
  }, true)
  local out5 = all_output()
  T("fluxo longo sem ESC[1A", not out5:find("\27[1A", 1, true))
  T("fluxo longo sem ESC[2K", not out5:find("\27[2K", 1, true))
  T("fluxo longo usa alternate screen", out5:find("\27[?1049h", 1, true) ~= nil)
  T("status final na main", out5:find("Permitido uma vez", 1, true) ~= nil)
  restore_io()

end

return M
