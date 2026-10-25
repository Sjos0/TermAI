package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- tests/update_units_spec.lua
-- Testes unitários e de contrato do comando CLI `TermAI update`
-- Origem: Issue #41 / PR #42 (feature/41-cli-update)
-- Objetivo: trava de regressão para helpers puros, parsing de flags,
--           árvore de decisão (check / force / dry-run / dirty / already-up-to-date),
--           registro real em main.lua/help.lua e contratos pós-d712060
--           (BASE_Q, read_remote_version, formato Remoto: versão + SHA).
--
-- "E se isso mudar?": qualquer alteração futura em short_sha, leitura de
-- VERSION, mensagens de erro acionáveis, clean-check obrigatório,
-- preferência por reset --hard, quoting de BASE ou versão remota no
-- --check/--dry-run deve falhar aqui antes de chegar ao usuário no Termux.
--
-- Nota: commands/update.lua é script top-level com funções locais e I/O
-- git. Não alteramos produção (escopo Agente de Testes). Helpers puros
-- reimplementados; registro e design validados por leitura real dos fontes
-- quando o cwd é a raiz do clone.


package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local harness = require("tests.helpers.harness")

print("\n=== Unit tests: commands/update (Issue #41 / PR #42) ===\n")

-- Partes em ordem. Cada uma adiciona ao mesmo placar (tests/helpers/harness.lua).
for _, parte in ipairs({
  "tests.update_units_spec.helpers_puros",
  "tests.update_units_spec.flags_decisao",
  "tests.update_units_spec.contratos_registro",
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
  print("✅ Todos os testes unitários/contratuais do comando update passaram")
end
