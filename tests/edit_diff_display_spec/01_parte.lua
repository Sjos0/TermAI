-- tests/edit_diff_display_spec/01_parte.lua — parte de edit_diff_display_spec.lua (ver fachada).
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


  -- ═══════════════════════════════════════════════════════════════════
  -- 1. TESTES DO diff_builder
  -- ═══════════════════════════════════════════════════════════════════
  sec("1. diff_builder.build()")

  do
    local before = "linha 1\nlinha 2\nlinha 3\nlinha 4\n"
    local patches = {{ old = "linha 2", new = "linha 2 modificada" }}
    local diff, added, removed = diff_builder.build(before, patches)
    T("Caso 1: diff não é nil", diff ~= nil)
    T("Caso 1: added > 0", added and added > 0, "added=" .. tostring(added))
    T("Caso 1: removed > 0", removed and removed > 0, "removed=" .. tostring(removed))
    T("Caso 1: diff contém标记 '+'", diff and diff:find("+") ~= nil)
    T("Caso 1: diff contém标记 '-'", diff and diff:find("-") ~= nil)
    if diff then print("    Diff:\n" .. diff) end
  end

  -- Caso 2: before_content com old_text que NÃO existe
  do
    local before = "linha 1\nlinha 2\nlinha 3\n"
    local patches = {{ old = "TEXTO INEXISTENTE", new = "novo" }}
    local diff, added, removed = diff_builder.build(before, patches)
    T("Caso 2: diff é nil quando old_text não existe", diff == nil)
    T("Caso 2: added é 0", added == 0)
    T("Caso 2: removed é 0", removed == 0)
  end

  -- Caso 3: before_content é nil
  do
    local patches = {{ old = "algo", new = "novo" }}
    local diff, added, removed = diff_builder.build(nil, patches)
    T("Caso 3: diff é nil quando before_content é nil", diff == nil)
  end

  -- Caso 4: before_content é string vazia
  do
    local patches = {{ old = "algo", new = "novo" }}
    local diff, added, removed = diff_builder.build("", patches)
    T("Caso 4: diff é nil quando before_content é vazio", diff == nil)
  end

  -- Caso 5: patch tipo "lines" (start_line/end_line)
  do
    local before = "aaa\nbbb\nccc\nddd\neee\n"
    local patches = {{ type = "lines", ls = 2, le = 3, new = "BBB\nCCC" }}
    local diff, added, removed = diff_builder.build(before, patches)
    T("Caso 5: patch lines funciona", diff ~= nil, "diff=" .. tostring(diff))
    if diff then print("    Diff:\n" .. diff) end
  end

  -- Caso 6: Simula o que o flush faz — edita memory/2026-08-11.md
  do
    local before = "# Memória - 2026-08-11 (Terça-feira)\n\n## Alternate Screen PR #24\nLinha de teste.\n"
    local patches = {{ old = "Linha de teste.", new = "Linha de teste.\n\n## Nova seção adicionada pelo flush\nConteúdo novo." }}
    local diff, added, removed = diff_builder.build(before, patches)
    T("Caso 6: flush-like edit gera diff", diff ~= nil)
    T("Caso 6: added > 0", added and added > 0, "added=" .. tostring(added))
    if diff then print("    Diff:\n" .. diff) end
  end

  -- ═══════════════════════════════════════════════════════════════════
  -- 2. TESTES DO result_builder (pipeline completo)
  -- ═══════════════════════════════════════════════════════════════════
end

return M
