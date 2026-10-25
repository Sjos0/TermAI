-- tests/google_grounding_pr5_spec.lua
-- Teste de isolamento: google_grounding com Interactions API + fallback chain
package.path = "./?.lua;./?/init.lua;" .. os.getenv("HOME") .. "/TermAI/?.lua;" .. os.getenv("HOME") .. "/TermAI/?/init.lua;" .. package.path

local harness = require("tests.helpers.harness")
local D = require("tests.google_grounding_pr5_spec.dobles")

print("\n=== Teste de Isolamento: Google Grounding (Interactions API + Fallback) ===\n")

for _, parte in ipairs({
  "tests.google_grounding_pr5_spec.parte_a",
  "tests.google_grounding_pr5_spec.parte_b",
}) do
  require(parte).run()
end

-- ═══════════════════════════════════════════════════════
-- RESTAURAR
-- ═══════════════════════════════════════════════════════

D.config_mod.load = D.orig_load
io.popen = D.orig_popen
os.remove = D.orig_remove
io.open = D.orig_open

-- ═══════════════════════════════════════════════════════
-- RESULTADO
-- ═══════════════════════════════════════════════════════

print(string.format(
  "\n══ RESULTADO: %d passaram, %d falharam (total: %d) ══",
  harness.pass, harness.fail, harness.pass + harness.fail))

if harness.fail > 0 then
  print("⚠️  FALHA DETECTADA")
  os.exit(1)
else
  print("✅ Todos os testes passaram")
end
