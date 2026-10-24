package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- tests/subagents_failures_spec.lua — Falhas de subagentes: requisição esgotada, stream cortado,
-- PID reaproveitado, deadline do SO e retomada depois que o orquestrador morre.
package.path = "./?.lua;./?/init.lua;" .. package.path

local C = require("tests.subagents_failures_spec.contexto")

for _, parte in ipairs({
  "tests.subagents_failures_spec.parte_a",
  "tests.subagents_failures_spec.parte_b",
}) do
  require(parte).run()
end

-- Limpeza do diretório de teste (antes de encerrar, como antes).
os.execute("rm -rf '" .. C.tmp .. "'")
local failures = C.failures_count()
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
