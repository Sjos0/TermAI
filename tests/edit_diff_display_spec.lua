-- tests/edit_diff_display_spec.lua — Investigação do bug: Edit não mostra diff na TUI
-- Testa diff_builder e edit_renderer isoladamente para isolar a causa raiz.

package.path = "./?.lua;./?/init.lua;./tools/?.lua;./tools/editor/?.lua;" .. package.path

local pass, fail = 0, 0
local function T(name, ok, detail)
  if ok then pass = pass + 1; print("  ✅ " .. name)
  else fail = fail + 1; print("  ❌ " .. name .. (detail and (" — " .. detail) or "")) end
end

local function sec(title) print("\n=== " .. title .. " ===") end

-- ═══════════════════════════════════════════════════════════════════
-- 1. TESTES DO diff_builder
-- ═══════════════════════════════════════════════════════════════════
sec("1. diff_builder.build()")

local diff_builder = require("tools.editor.diff_builder")

-- Caso 1: before_content com old_text que existe
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
sec("2. result_builder.build()")

local result_builder = require("tools.editor.result_builder")

local function fake_file_info(content)
  return "📊 " .. #content .. " chars"
end
local function fake_luac(path)
  return nil  -- sem validação
end

-- Caso 1: resultado com diff
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
sec("3. edit_renderer.render_edit_body() — mock de IO")

local edit_renderer = require("ui.tools_init.edit_renderer")

-- Mock de io.write para capturar output
local captured_output = {}
local orig_write = io.write
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
print("\n" .. string.rep("═", 60))
print(string.format("EDIT DIFF DISPLAY: %d passaram, %d falharam", pass, fail))
print(string.rep("═", 60))
if fail > 0 then os.exit(1) end
