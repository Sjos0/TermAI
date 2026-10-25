package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- tests/exec_permissions_spec.lua — Testes unitários para o sistema de permissões e segurança bash

package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local harness = require("tests.helpers.harness")

for _, parte in ipairs({
  "tests.exec_permissions_spec.01_parte",
  "tests.exec_permissions_spec.02_parte",
}) do
  require(parte).run()
end

print("\n" .. string.rep("═", 60))
print(string.format("RESULTADO DOS TESTES DE PERMISSÕES BASH: %d passaram, %d falharam", harness.pass, harness.fail))
print(string.rep("═", 60))

if harness.fail > 0 then
  os.exit(1)
end

