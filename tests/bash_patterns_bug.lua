package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- bash_patterns_bug.lua — Testes para bug de persistência de permissões
-- Executar: lua5.4 ~/TermAI/tests/bash_patterns_bug.lua

package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. os.getenv("HOME") .. "/TermAI/?.lua;" .. os.getenv("HOME") .. "/TermAI/?/init.lua;" .. package.path
local harness = require("tests.helpers.harness")

for _, parte in ipairs({
  "tests.bash_patterns_bug.01_1_parser",
  "tests.bash_patterns_bug.02_6_heredoc_corrigido",
  "tests.bash_patterns_bug.03_8_hunter_bugfixes",
}) do
  require(parte).run()
end

print("\n" .. string.rep("═", 60))
print(string.format("RESULTADO: %d passaram, %d falharam (total: %d)", harness.pass, harness.fail, harness.pass + harness.fail))
print(string.rep("═", 60))
if harness.fail > 0 then os.exit(1) end

