-- agent/harness/modelo.lua — Deps reais do ciclo.
-- propor/escolher: chamadas simples, sem streaming, sem ferramentas.
-- testar (probe): roda a tarefa pelo loop real do agente, com ferramentas, num contexto
-- isolado (is_subagent) e num workspace temporário e vazio, sem histórico do usuário.
-- Limitação: caminhos absolutos citados na tarefa ainda alcançam o disco real. Antes de
-- ligar isso em uso real, é preciso uma barreira de caminhos (ainda não existe).
local M = {}

local function pensar(prompt)
  local context = require("agent.context")
  local api     = require("agent.api.request_sync")
  local ctx     = context.build({ is_subagent = true, agent_id = "harness2" })
  local texto   = api.pensar_sync(ctx, prompt, "user")
  if type(texto) ~= "string" or texto == "" or texto:match("^%[ERRO") then
    error("modelo sem resposta utilizável")
  end
  return texto
end

local function probe(prompt, tarefa)
  local context = require("agent.context")
  local loop    = require("agent.loop")
  local tmp = os.tmpname()
  os.remove(tmp)
  os.execute("mkdir -p '" .. tmp .. "'")
  local ctx = context.build({ is_subagent = true, agent_id = "harness2", workspace = tmp })
  ctx.MAX_ITER = 6
  local resp, _, _, overflow, complete =
    loop.rodar(ctx, prompt .. "\n\nTAREFA:\n" .. tarefa, "user", ctx.MAX_ITER)
  os.execute("rm -rf '" .. tmp .. "'")
  if overflow or complete == false or type(resp) ~= "string" or resp == ""
     or resp:match("^%[ERRO") then
    error("probe sem resposta utilizável")
  end
  return resp
end

-- Embaralha as saídas e as apresenta com rótulos anônimos (X, Y, Z).
local function montar_escolha(saidas)
  local nomes = {}
  for _, nome in ipairs({ "base", "A", "B" }) do
    if saidas[nome] then nomes[#nomes + 1] = nome end
  end
  for i = #nomes, 2, -1 do
    local j = math.random(i)
    nomes[i], nomes[j] = nomes[j], nomes[i]
  end
  local rotulos = { "X", "Y", "Z" }
  local mapa, partes = {}, {}
  for i, nome in ipairs(nomes) do
    mapa[rotulos[i]] = nome
    partes[#partes + 1] = "Resposta " .. rotulos[i] .. ":\n" .. saidas[nome]
  end
  local pedido = "Abaixo estão respostas a uma mesma tarefa. Escolha a melhor e responda SOMENTE "
    .. "com a letra dela (X, Y ou Z).\n\n" .. table.concat(partes, "\n\n---\n\n")
  return pedido, mapa
end

function M.deps(tarefa)
  math.randomseed(os.time())
  return {
    propor = function(base, dimensao)
      return pensar("Proponha UMA versão alterada do prompt de sistema abaixo, focada em "
        .. dimensao .. ". Responda somente com o texto do prompt novo.\n\n" .. base)
    end,
    testar = function(prompt)
      return probe(prompt, tarefa)
    end,
    escolher = function(saidas)
      local pedido, mapa = montar_escolha(saidas)
      local resp = pensar(pedido):upper():match("[XYZ]")
      return resp and mapa[resp] or nil
    end,
  }
end

return M
