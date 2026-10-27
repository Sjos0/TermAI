package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- tests/harness2_ciclo_spec.lua — Harness² Fase 1: ciclo com respostas simuladas.
-- As respostas aqui não medem qualidade; só checam que o código do caminho funciona.
local ciclo   = require("agent.harness.ciclo")
local adocao  = require("agent.harness.adocao")
local harness = require("agent.harness")

local falhas = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else falhas = falhas + 1; print("FAIL: " .. msg) end
end

local function deps(over)
  local d = {
    propor  = function(base, dim) return base .. "+" .. dim end,
    testar  = function(cand) return "saida(" .. cand .. ")" end,
    escolher = function(saidas) return "A" end,
  }
  for k, v in pairs(over or {}) do d[k] = v end
  return d
end

local r = ciclo.rodar("BASE", deps())
check(r.adotado == true and r.candidato == "A", "escolhe candidato A quando o seletor responde A")
check(r.conteudo == "BASE+invariante", "conteúdo adotado é o candidato A")

r = ciclo.rodar("BASE", deps({ escolher = function() return "base" end }))
check(r.adotado == false and r.motivo == "base_mantida", "seletor escolhe base: nada é adotado")

r = ciclo.rodar("BASE", deps({ escolher = function() return nil end }))
check(r.adotado == false and r.motivo == "fallback_base", "seletor sem resposta cai na base")

r = ciclo.rodar("BASE", deps({ escolher = function() error("api caiu") end }))
check(r.adotado == false and r.motivo == "fallback_base", "seletor com erro cai na base")

r = ciclo.rodar("BASE", deps({ escolher = function() return "Z" end }))
check(r.adotado == false and r.motivo == "fallback_base", "seletor inventa rótulo: cai na base")

r = ciclo.rodar("BASE", deps({ propor = function() error("sem resposta") end }))
check(r.adotado == false and r.motivo == "sem_proposta", "nenhuma proposta: ciclo não adota")

r = ciclo.rodar("BASE", deps({
  testar = function(c) if c == "BASE+invariante" then error("timeout") end return "saida(" .. c .. ")" end,
  escolher = function(s) return s.B and "B" or "base" end,
}))
check(r.adotado == true and r.candidato == "B", "candidato A que falha no teste sai; B continua válido")

r = ciclo.rodar("BASE", deps({
  testar = function(c) if c == "BASE" then error("sem final") end return "saida(" .. c .. ")" end,
}))
check(r.adotado == false and r.motivo == "base_sem_resposta", "referência sem resposta: o ciclo não quebra e não adota")

check(adocao.nome_valido("harness.md") and not adocao.nome_valido("../x.md"),
      "nome de arquivo sem barra é aceito; com caminho é recusado")

local dir = os.getenv("TMPDIR") or "/tmp"
dir = dir .. "/harness2_spec_" .. tostring(os.time())
local ok = adocao.gravar(dir, "harness.md", "conteudo novo")
local f = ok and io.open(dir .. "/harness.md", "r")
local lido = f and f:read("*a")
if f then f:close() end
check(ok == true and lido == "conteudo novo", "gravação atômica escreve o conteúdo no destino")
check(select(2, io.open(dir .. "/harness.md.tmp", "r")) ~= nil, "arquivo temporário não sobra depois da troca")
os.execute("rm -rf '" .. dir .. "'")

check(adocao.gravar("/tmp/x'y", "a.md", "x") == nil, "diretório com aspas é recusado")

check(harness.depois_do_turno({}).status == "desativado",
      "gancho com a opção desligada não faz nada (estado 'desativado')")

print(falhas == 0 and "TODOS OS TESTES PASSARAM" or ("FALHAS: " .. falhas))
os.exit(falhas == 0 and 0 or 1)
