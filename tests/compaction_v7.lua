package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- test_compaction_v7.lua — Fase 1+5 (unitários + adversariais)
-- Executar: lua5.4 ~/test_compaction_v7.lua

package.path = "./?.lua;./?/init.lua;" .. os.getenv("HOME") .. "/TermAI/?.lua;" .. os.getenv("HOME") .. "/TermAI/?/init.lua;" .. package.path
local harness = require("tests.helpers.harness")

for _, parte in ipairs({
  "tests.compaction_v7.01_1_cutpoint",
  "tests.compaction_v7.02_6_filetracking",
}) do
  require(parte).run()
end

print("\n" .. string.rep("═", 60))
print(string.format("RESULTADO: %d passaram, %d falharam (total: %d)", harness.pass, harness.fail, harness.pass + harness.fail))
print(string.rep("═", 60))
if harness.fail > 0 then os.exit(1) end

