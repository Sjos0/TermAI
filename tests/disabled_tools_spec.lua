-- tests/disabled_tools_spec.lua
-- Regressão Issue #32 / PR #46: desativação de tools por agente.
--
-- "E se isso mudar?": se get_schema voltar a ignorar o filtro, se a ordem
-- deixar de ser estável, se call* deixar de recusar tool desativada, ou se
-- callers sem 2º arg quebrarem — este arquivo grita antes da TUI.
--
-- Escopo: fachada tools (get_schema, get_docs, call, call_structured)
-- + contrato estático do runner / path XML (propagação de disabled_tools).
-- Não cobre menus TUI/CLI (I/O interativo) nem persistência em config.json
-- (integração com filesystem do usuário).


package.path = "./?.lua;./?/init.lua;" .. package.path
local harness = require("tests.helpers.harness")

for _, parte in ipairs({
  "tests.disabled_tools_spec.01_parte",
  "tests.disabled_tools_spec.02_parte",
  "tests.disabled_tools_spec.03_parte",
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
  print("✅ Todos os testes de desativação de tools (#32) passaram")
end

