package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- tests/doc_gap_surfaces_spec.lua
-- Regressão PR #68 / Issues #55 #56 #54 (e inventário alinhado ao batch DOC-GAP).
--
-- "E se isso mudar?": se /compact ou /status sumirem de available.lua, se
-- /help da TUI voltar a dofile da ajuda CLI, ou se skills/npx/restart
-- sumirem do mapa CLI — este arquivo grita antes do usuário na TUI.
--
-- Escopo: contratos de superfície (lista canônica + wiring). Não cobre
-- ortografia do README nem inventário amostral de status.lua.


package.path = "./?.lua;./?/init.lua;" .. package.path
local harness = require("tests.helpers.harness")

for _, parte in ipairs({
  "tests.doc_gap_surfaces_spec.01_n_unit_tests_superf_cies_d",
  "tests.doc_gap_surfaces_spec.02_parte",
}) do
  require(parte).run()
end

print(string.format(
  "\n══ RESULTADO: %d passaram, %d falharam (total: %d) ══",
  harness.pass, harness.fail, harness.pass + harness.fail))

if harness.fail > 0 then
  print("⚠️  FALHA DETECTADA")
  os.exit(1)
else
  print("✅ Contratos de superfície DOC-GAP (#55 #56 #54) ok")
end

