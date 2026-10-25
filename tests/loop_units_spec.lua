package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- tests/loop_units_spec.lua
-- Testes dos submódulos extraídos em agent/loop/
-- Origem: Issue #29 / PR #40 (branch refactor/29-agent-loop-facade)
-- Objetivo: trava de regressão para response_utils, system_messages,
--           json_path e xml_path — protocolo do loop ReAct isolável
--           sem API real nem I/O de rede.
--
-- "E se isso mudar?": qualquer alteração em strip de FLUSH_DONE,
-- detecção de intent não cumprido, injeções de boot/restart/cancel,
-- cancelamento atômico JSON, retries vazio/unfulfilled XML ou no
-- contrato {action=return|continue|retry} deve falhar aqui antes
-- de chegar à fachada M.rodar.
--
-- Tipos cobertos:
--   * unitário puro (response_utils)
--   * unitário com doubles (system_messages, json_path, xml_path)
--   * caso extremo (nil, vazio, bordas de retry, prefixos de erro)
--   * contrato estrutural das actions devolvidas aos paths
--   * regressão de comportamento do monólito (Issue #29)
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local harness = require("tests.helpers.harness")

-- Silencia io.write/io.flush dos auto-retries durante os testes (restaurado no fim)
local _io_write, _io_flush = io.write, io.flush
io.write = function() end
io.flush = function() end

print("\n=== Unit tests: agent/loop submodules (Issue #29 / PR #40) ===\n")

-- Dublês compartilhados (ui, tool_runner, tools_handler, memória) são instalados ao carregar.
require("tests.loop_units_spec.dobles")

-- Partes em ordem. Cada uma adiciona ao mesmo placar (tests/helpers/harness.lua).
for _, parte in ipairs({
  "tests.loop_units_spec.response_utils",
  "tests.loop_units_spec.system_messages",
  "tests.loop_units_spec.json_path",
  "tests.loop_units_spec.xml_path",
  "tests.loop_units_spec.integracao",
}) do
  require(parte).run()
end

io.write = _io_write
io.flush = _io_flush

print(string.format(
  "\n══ RESULTADO: %d passaram, %d falharam (total: %d) ══",
  harness.pass, harness.fail, harness.pass + harness.fail))

if harness.fail > 0 then
  print("⚠️  FALHA DETECTADA")
  os.exit(1)
else
  print("✅ Todos os testes dos submódulos agent/loop passaram")
end
