-- tests/permissions_check_spec.lua — Testes unitários do módulo check (PR #33 / Issue #26)
-- ATENÇÃO: depende de config.json, session e parser. Sempre restaura estado.

package.path = "./?.lua;./?/init.lua;" .. package.path
local harness = require("tests.helpers.harness")

for _, parte in ipairs({
  "tests.permissions_check_spec.01_parte",
  "tests.permissions_check_spec.02_4_hooks_permissions_config",
  "tests.permissions_check_spec.03_7_deny_prioridade_sobre_al",
  "tests.permissions_check_spec.04_10_comando_desconhecido",
}) do
  require(parte).run()
end

print("\nRESULTADO: " .. harness.pass .. " passaram, " .. harness.fail .. " falharam")
if harness.fail > 0 then os.exit(1) end

