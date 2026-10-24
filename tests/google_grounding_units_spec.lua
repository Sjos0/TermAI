package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- tests/google_grounding_units_spec.lua
-- Testes unitários dos submódulos extraídos em providers/google_grounding/
-- Origem: Issue #27 / PR #37 (refactor monólito → fachada + submódulos)
-- Objetivo: trava de regressão para error_classifier, response_extractor,
--           formatter e constants — módulos de responsabilidade única
--           agora isoláveis sem I/O de rede.
--
-- "E se isso mudar?": qualquer alteração futura em classificação de erro,
-- extração de steps/annotations ou formatação de saída deve falhar aqui
-- antes de chegar ao usuário.


package.path = "./?.lua;./?/init.lua;" .. package.path
local harness = require("tests.helpers.harness")

for _, parte in ipairs({
  "tests.google_grounding_units_spec.01_n_unit_tests_google_ground",
  "tests.google_grounding_units_spec.02_response_extractor_extract",
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
  print("✅ Todos os testes unitários dos submódulos passaram")
end
