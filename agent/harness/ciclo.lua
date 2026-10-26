-- agent/harness/ciclo.lua — Ciclo Propose–Probe–Compose, puro (sem rede e sem disco).
-- Todas as chamadas ao modelo entram por deps, para que os testes usem respostas simuladas.
--   deps.propor(base, dimensao)  -> candidato (string) ou erro
--   deps.testar(candidato)       -> saída (string) ou erro
--   deps.escolher(saidas)        -> rótulo escolhido ("base", "A", "B") ou nil
-- Retorna { adotado = bool, candidato = rótulo|nil, motivo = texto }.
local M = {}

function M.rodar(base, deps)
  local candidatos = {}
  for _, par in ipairs({ { "A", "invariante" }, { "B", "dominio" } }) do
    local ok, cand = pcall(deps.propor, base, par[2])
    if ok and type(cand) == "string" and cand ~= "" then candidatos[par[1]] = cand end
  end
  if not candidatos.A and not candidatos.B then
    return { adotado = false, motivo = "sem_proposta" }
  end

  -- Probe: a base é a referência; cada candidato roda a mesma tarefa.
  local saidas = {}
  for rotulo, cand in pairs(candidatos) do
    local ok, saida = pcall(deps.testar, cand)
    if ok and type(saida) == "string" then saidas[rotulo] = saida end
  end
  saidas.base = deps.testar(base) -- a referência não é protegida por pcall: erro aqui aborta o ciclo

  -- Compose: escolha entre saídas anônimas. Qualquer falha cai na base.
  local ok, escolha = pcall(deps.escolher, saidas)
  if not ok or escolha == nil or saidas[escolha] == nil then
    return { adotado = false, motivo = "fallback_base" }
  end
  if escolha == "base" then
    return { adotado = false, motivo = "base_mantida" }
  end
  return { adotado = true, candidato = escolha, motivo = "candidato_escolhido",
           conteudo = candidatos[escolha] }
end

return M
