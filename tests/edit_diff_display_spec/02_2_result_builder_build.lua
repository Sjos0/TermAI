-- tests/edit_diff_display_spec/02_2_result_builder_build.lua — parte de edit_diff_display_spec.lua (ver fachada).
local harness = require("tests.helpers.harness")

local M = {}

function M.run()
  local captured_output = {}
  local orig_write = io.write

  local function T(name, ok, detail)
    if ok then harness.pass = harness.pass + 1; print("  ✅ " .. name)
    else harness.fail = harness.fail + 1; print("  ❌ " .. name .. (detail and (" — " .. detail) or "")) end
  end

  local function sec(title) print("\n=== " .. title .. " ===") end

  local diff_builder = require("tools.editor.diff_builder")

  -- Caso 1: before_content com old_text que existe

  local result_builder = require("tools.editor.result_builder")

  local function fake_file_info(content)
    return "📊 " .. #content .. " chars"
  end

  local function fake_luac(path)
    return nil  -- sem validação
  end

  -- Caso 1: resultado com diff

  local edit_renderer = require("ui.tools_init.edit_renderer")

  -- Mock de io.write para capturar output

  local function install_mock()
    captured_output = {}
    io.write = function(...)
      local parts = {}
      for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
      captured_output[#captured_output + 1] = table.concat(parts)
    end
  end

  local function restore_mock()
    io.write = orig_write
  end

  local function get_output()
    return table.concat(captured_output)
  end

  -- Renderer 1: diff com mudanças reais


  sec("2. result_builder.build()")


  do
    local before = "aaa\nbbb\nccc\n"
    local patches = {{ old = "bbb", new = "BBB" }}
    local msg = "Substituição aplicada ✓ (1 patch)"
    local result = result_builder.build("/fake/path.lua", msg, patches, before, fake_file_info, fake_luac)
    T("Result 1: resultado não é nil", result ~= nil)
    T("Result 1: contém METRICS", result and result:find("METRICS") ~= nil)
    T("Result 1: contém diff", result and result:find("BBB") ~= nil)
    T("Result 1: contém '+' marker", result and result:find("+") ~= nil)
    T("Result 1: contém '-' marker", result and result:find("-") ~= nil)
    if result then print("    Result:\n" .. result:sub(1, 500)) end
  end

  -- Caso 2: resultado SEM diff (before_content nil)
  do
    local patches = {{ old = "bbb", new = "BBB" }}
    local msg = "Substituição aplicada ✓ (1 patch)"
    local result = result_builder.build("/fake/path.lua", msg, patches, nil, fake_file_info, fake_luac)
    T("Result 2: resultado não é nil", result ~= nil)
    T("Result 2: NÃO contém METRICS", result and result:find("METRICS") == nil)
    T("Result 2: contém msg", result and result:find("Substituição") ~= nil)
    if result then print("    Result:\n" .. result:sub(1, 300)) end
  end

  -- Caso 3: resultado com zero change (old = new)
  do
    local before = "aaa\nbbb\nccc\n"
    local patches = {{ old = "bbb", new = "bbb" }}
    local msg = "Substituição aplicada ✓ (1 patch)"
    local result = result_builder.build("/fake/path.lua", msg, patches, before, fake_file_info, fake_luac)
    T("Result 3: detecta zero change", result and result:find("Nenhuma alteração") ~= nil)
    if result then print("    Result:\n" .. result:sub(1, 300)) end
  end

  -- ═══════════════════════════════════════════════════════════════════
  -- 3. TESTES DO edit_renderer (mock de IO)
  -- ═══════════════════════════════════════════════════════════════════
end

return M
