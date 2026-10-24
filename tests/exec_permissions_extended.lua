-- tests/exec_permissions_extended.lua — Testes estendidos (fachada).
-- Complementa exec_permissions_spec.lua. Os cenários estão em tests/exec_permissions_extended/
-- e rodam nesta ordem: a parte de estado configura o config que as seguintes usam.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local harness = require("tests.helpers.harness")

for _, parte in ipairs({
  "tests.exec_permissions_extended.security",
  "tests.exec_permissions_extended.matching_state",
  "tests.exec_permissions_extended.modes",
}) do
  require(parte).run()
end

print("\n" .. string.rep("═", 60))
print(string.format("TESTES ESTENDIDOS: %d passaram, %d falharam", harness.pass, harness.fail))
print(string.rep("═", 60))

if harness.fail > 0 then
  os.exit(1)
end
