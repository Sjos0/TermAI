-- tests/edit_diff_display_spec/03_3_edit_renderer_render_edi.lua — parte de edit_diff_display_spec.lua (ver fachada).
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


  sec("3. edit_renderer.render_edit_body() — mock de IO")

  do
    install_mock()
    local lines = {
      'METRICS: added=2, removed=1',
      '  1   | linha 1',
      '  2 - | linha 2 antiga',
      '  2 + | linha 2 nova',
      '  2 + | linha 2 extra',
      '  3   | linha 3',
    }
    edit_renderer.render_edit_body(lines, true, 80)
    local out = get_output()
    restore_mock()
    T("Renderer 1: contém 'Adicionadas'", out:find("Adicionadas") ~= nil)
    T("Renderer 1: contém 'Substituição concluída'", out:find("Substituição concluída") ~= nil)
    T("Renderer 1: contém linha com '+'", out:find("+") ~= nil)
    T("Renderer 1: contém linha com '-'", out:find("-") ~= nil)
    print("    Output:\n" .. out:sub(1, 500))
  end

  -- Renderer 2: diff SEM mudanças (linhas de contexto apenas)
  do
    install_mock()
    local lines = {
      'METRICS: added=0, removed=0',
      '  1   | linha 1',
      '  2   | linha 2',
      '  3   | linha 3',
    }
    edit_renderer.render_edit_body(lines, true, 80)
    local out = get_output()
    restore_mock()
    T("Renderer 2: contém 'Substituição concluída'", out:find("Substituição concluída") ~= nil)
    T("Renderer 2: SEM marker '+'", not out:find("+"))
    T("Renderer 2: SEM marker '-'", not out:find("-"))
    print("    Output:\n" .. out:sub(1, 500))
  end

  -- Renderer 3: LINHAS VAZIAS (simula diff nil → sem linhas de diff)
  do
    install_mock()
    local lines = {
      'Substituição aplicada ✓ (1 patch)',
    }
    edit_renderer.render_edit_body(lines, true, 80)
    local out = get_output()
    restore_mock()
    T("Renderer 3: contém 'Substituição concluída'", out:find("Substituição concluída") ~= nil)
    T("Renderer 3: SEM diff visível", not out:find("+") and not out:find("-"))
    print("    Output:\n" .. out:sub(1, 500))
  end

  -- ═══════════════════════════════════════════════════════════════════
  -- 4. TESTE DO PIPELINE COMPLETO (diff_builder → result_builder → renderer)
  -- ═══════════════════════════════════════════════════════════════════
end

return M
