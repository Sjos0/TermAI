-- tests/edit_diff_display_spec/04_4_pipeline_completo_simula.lua — parte de edit_diff_display_spec.lua (ver fachada).
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


  sec("4. Pipeline completo (simula o que o Edit faz)")

  do
    -- Simula o fluxo do editor.lua
    local before_content = "# Memória\n\n## Seção antiga\nConteúdo velho.\n"
    local edits = {{ old = "Conteúdo velho.", new = "Conteúdo novo.\n\n## Seção nova\nMais conteúdo." }}
    local msg = "Substituição aplicada ✓ (1 patch)"

    -- Passo 1: result_builder gera o resultado
    local result = result_builder.build("/fake/memory.md", msg, edits, before_content, fake_file_info, fake_luac)
    T("Pipeline: result_builder gerou resultado", result ~= nil)

    -- Passo 2: split em linhas (como o executor faz)
    local raw_lines = {}
    for ln in (result .. "\n"):gmatch("([^\n]*)\n") do
      if ln ~= "" then raw_lines[#raw_lines + 1] = ln end
    end
    T("Pipeline: " .. #raw_lines .. " linhas extraídas", #raw_lines > 0)

    -- Passo 3: renderiza
    install_mock()
    edit_renderer.render_edit_body(raw_lines, true, 80)
    local out = get_output()
    restore_mock()

    T("Pipeline: output contém diff", out:find("Adicionadas") ~= nil)
    T("Pipeline: output contém 'Substituição concluída'", out:find("Substituição concluída") ~= nil)
    print("    Output completo:\n" .. out)
  end

  -- ═══════════════════════════════════════════════════════════════════
  -- 5. TESTE CRÍTICO: o que acontece quando o resultado NÃO tem diff
  -- ═══════════════════════════════════════════════════════════════════
  sec("5. Caso crítico: resultado sem diff (simula o bug)")

  do
    -- Simula quando result_builder retorna só a msg sem diff
    -- Isso acontece quando should_diff(msg) retorna false
    local result = "Substituição aplicada ✓ (1 patch)"

    local raw_lines = {}
    for ln in (result .. "\n"):gmatch("([^\n]*)\n") do
      if ln ~= "" then raw_lines[#raw_lines + 1] = ln end
    end

    install_mock()
    edit_renderer.render_edit_body(raw_lines, true, 80)
    local out = get_output()
    restore_mock()

    T("Bug: output mostra 'Substituição concluída' SEM diff", out:find("Substituição concluída") ~= nil)
    T("Bug: output NÃO contém linhas de diff", not out:find("+") and not out:find("-"))
    print("    Output (BUG REPRODUZIDO):\n" .. out)
  end

  -- ═══════════════════════════════════════════════════════════════════
  -- RESULTADO
  -- ═══════════════════════════════════════════════════════════════════
end

return M
