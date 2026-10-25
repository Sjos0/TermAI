package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- tests/security_validation_pr5_spec.lua
-- PR #5: Sentinel — Fix potential command injection
-- Testa a proteção contra injeção de comandos em endpoints e API keys

package.path = os.getenv("HOME") .. "/TermAI/?.lua;" .. os.getenv("HOME") .. "/TermAI/?/init.lua;" .. package.path
local harness = require("tests.helpers.harness")

for _, parte in ipairs({
  "tests.security_validation_pr5_spec.01_n_pr_5_sentinel_command_in",
  "tests.security_validation_pr5_spec.02_parte",
  "tests.security_validation_pr5_spec.03_n_fase_5_adversarial_edge_",
}) do
  require(parte).run()
end

print(string.format(
  "\n══ RESULTADO: %d passaram, %d falharam, %d pulados (total: %d) ══",
  harness.pass, harness.fail, harness.skip, harness.pass + harness.fail + harness.skip))

if harness.fail > 0 then
  print("⚠️  FALHA DETECTADA — revisar antes de merge")
  os.exit(1)
else
  print("✅ Todos os testes passaram")
end

