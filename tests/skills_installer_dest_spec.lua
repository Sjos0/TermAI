-- tests/skills_installer_dest_spec.lua
-- Regressão Issue #72 / PR #75: destino do CLI installer = SSOT do runtime.
--
-- "E se isso mudar?": se get_dest voltar a gravar em ~/.TermAI/agents/,
-- se github_installer forçar global, ou se defaults de install_from_*
-- hardcodarem HOME/.TermAI/skills fora do SSOT — este arquivo grita.
--
-- Tipos: unitário (paths puros), oracle (installer.utils ≡ skills.utils),
-- invariante (nunca /agents/), contrato estático (leitura de fontes),
-- bordas (nil, main, agent nomeado, flags vazios).


package.path = "./?.lua;./?/init.lua;" .. package.path
local harness = require("tests.helpers.harness")

print("\n=== Unit tests: skills installer dest SSOT (Issue #72 / PR #75) ===\n")

-- Partes em ordem. Cada uma adiciona ao mesmo placar (tests/helpers/harness.lua).
for _, parte in ipairs({
  "tests.skills_installer_dest_spec.ssot_dest",
  "tests.skills_installer_dest_spec.invariantes_contratos",
  "tests.skills_installer_dest_spec.cli_propriedades",
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
  print("✅ Regressão #72 / dest SSOT: todos os asserts passaram")
end
