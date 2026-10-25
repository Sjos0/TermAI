-- tests/fuzzy_match_pr4_spec.lua
-- Suíte de testes para validar a PR #4: Optimize fuzzy matching
-- Objetivo: Confirmar que a versão otimizada preserva 100% do comportamento atual
--
-- Fases de teste (conforme skill lua-testing):
--   Fase 0: Syntax gate (luac -p)
--   Fase 1: Isolamento — testes unitários de fuzzy_match.lua
--   Fase 3: Integração — fuzzy_match via error_feedback/init.lua
--   Fase 4: Fluxo — cenário real de uso (sugestão de ferramenta incorreta)
--   Fase 5: Adversarial — edge cases, inputs maliciosos, performance

-- SETUP (mesmo caminho de antes: HOME/TermAI primeiro, depois o diretório atual)
package.path = os.getenv("HOME") .. "/TermAI/?.lua;" .. os.getenv("HOME") .. "/TermAI/?/init.lua;" .. package.path
local harness = require("tests.helpers.harness")

-- Fases em ordem. Cada uma adiciona ao mesmo placar (tests/helpers/harness.lua).
for _, parte in ipairs({
  "tests.fuzzy_match_pr4_spec.isolamento",
  "tests.fuzzy_match_pr4_spec.integracao_fluxo",
  "tests.fuzzy_match_pr4_spec.adversarial",
}) do
  require(parte).run()
end

----------------------------------------------------------------------
print("\n" .. string.rep("═", 55))
print(string.format("RESULTADO: %d passaram, %d falharam, %d pulados", harness.pass, harness.fail, harness.skip))
print(string.rep("═", 55))

if harness.fail > 0 then
  print("\n⚠️  FALHAS DETECTADAS — revisar antes de merge!")
  os.exit(1)
else
  print("\n✅ TODOS OS TESTES PASSARAM — seguro para merge")
  os.exit(0)
end
