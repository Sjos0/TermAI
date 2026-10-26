-- Prepara o provedor Kilo e grava o modelo antes das tarefas (mesmo passo do e2e).
-- Sem isso, o TermAI para com "Nenhum modelo configurado" antes de ler --model.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local config = require("config")
require("e2e.common").ensure_kilo()
local modelo = os.getenv("BENCH_MODEL") or "kilo/kilo-auto/free"
if not config.set("agents.defaults.model.primary", modelo) then
  io.stderr:write("não foi possível gravar o modelo " .. modelo .. "\n")
  os.exit(2)
end
print("modelo preparado: " .. modelo)
