package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- tests/flush_units_spec.lua
-- Testes unitários dos submódulos extraídos em agent/flush/
-- Origem: Issue #28 / branch refactor/28-agent-flush-facade
-- Objetivo: trava de regressão para format_context, gate_detector e
--           checklist — módulos de responsabilidade única isoláveis
--           sem I/O de rede nem API.
--
-- "E se isso mudar?": qualquer alteração futura em formatação do
-- contexto de flush, detecção de gates FPM ou render do checklist
-- deve falhar aqui antes de chegar ao loop ReAct.
--
-- Nota: agent/flush/tests/T1|T2|T4 são stubs TDD conceituais que
-- reimplementam a lógica localmente. Este arquivo importa os módulos
-- REAIS e valida o comportamento de produção.
package.path = "./?.lua;./?/init.lua;" .. package.path
local harness = require("tests.helpers.harness")

print("\n=== Unit tests: agent/flush submodules (Issue #28) ===\n")

-- Partes em ordem. Cada uma adiciona ao mesmo placar (tests/helpers/harness.lua).
for _, parte in ipairs({
  "tests.flush_units_spec.checklist",
  "tests.flush_units_spec.format_context",
  "tests.flush_units_spec.gate_detector",
}) do
  require(parte).run()
end

-- RELATÓRIO
print(string.format(
  "\n══ RESULTADO: %d passaram, %d falharam (total: %d) ══",
  harness.pass, harness.fail, harness.pass + harness.fail))

if harness.fail > 0 then
  print("⚠️  FALHA DETECTADA")
  os.exit(1)
else
  print("✅ Todos os testes unitários dos submódulos flush passaram")
end
