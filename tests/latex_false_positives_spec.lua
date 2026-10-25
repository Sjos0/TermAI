-- tests/latex_false_positives_spec.lua
-- Regressão Issue #36: apply_latex não deve mutar paths, moeda nem substrings.
-- Também garante que math mode legítimo e standalone intencional continuam ok.
--
-- "E se isso mudar?": qualquer regressão em left-boundary, heurística de moeda,
-- pattern $$...$$ ou stripping de math legítimo deve falhar aqui antes de
-- chegar à TUI. Origem: Issue #36 / PR #45.
--
-- Políticas travadas pós-review (Caçador):
-- - Inline: dígito inicial + sem \\ → preserva $...$ (moeda / math numérico)
-- - Display $$...$$: sem heurística de moeda (stripping normal)
-- - Standalone: left boundary [%w\\:] + right boundary letra

local harness = require("tests.helpers.harness")

for _, parte in ipairs({
  "tests.latex_false_positives_spec.01_issue_36_falsos_positivos_",
  "tests.latex_false_positives_spec.02_n_casos_de_borda",
}) do
  require(parte).run()
end

print(string.format(
  "\n══ RESULTADO: %d passaram, %d falharam (total: %d) ══",
  harness.pass, harness.fail, harness.pass + harness.fail))

if harness.fail > 0 then
  print("⚠️  FALHA DETECTADA")
  os.exit(1)
else
  print("✅ Todos os testes de regressão #36 passaram!")
end

