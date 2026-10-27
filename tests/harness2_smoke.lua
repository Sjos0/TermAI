-- tests/harness2_smoke.lua — Uma execução real do ciclo com o Kilo (6 chamadas).
-- Manual, na VPS. Não roda no CI. Uso: TAREFA_ARQ=arquivo.md lua5.4 tests/harness2_smoke.lua
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
require("e2e.common").ensure_kilo()
require("config").set("agents.defaults.model.primary", "kilo/kilo-auto/free")
local ciclo  = require("agent.harness.ciclo")
local modelo = require("agent.harness.modelo")
local adocao = require("agent.harness.adocao")

local base = "Você é um agente que resolve tarefas no terminal. Responda com precisão e sem enrolação."
local arq = assert(os.getenv("TAREFA_ARQ"), "defina TAREFA_ARQ")
local tarefa = assert(io.open(arq, "r")):read("*a")

local r = ciclo.rodar(base, modelo.deps(tarefa))
print("RESULTADO adotado=" .. tostring(r.adotado) .. " candidato=" .. tostring(r.candidato)
  .. " motivo=" .. tostring(r.motivo))
if r.adotado then
  local dir = (os.getenv("HOME") or ".") .. "/.TermAI/harness"
  print("gravar: " .. tostring(adocao.gravar(dir, "harness.md", r.conteudo)))
end
