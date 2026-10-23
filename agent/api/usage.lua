-- agent/api/usage.lua — Consumo de tokens acumulado por run (issue: paridade OpenClaw, tokens por subagente).
-- Cada chamada ao provedor reporta seu usage; somamos chamada a chamada. O total do run é o que
-- foi cobrado: cada chamada reenvia o contexto inteiro, então a soma é maior que o tamanho final.
-- Limite: assume usage no último chunk de cada chamada (padrão com include_usage). Se um provedor
-- repetir usage em vários chunks da mesma chamada, a soma conta duas vezes.
local M = {}

-- Soma um bloco de usage do provedor no acumulador. Devolve o acumulador (cria se for nil).
function M.add(acc, usage)
  if type(usage) ~= "table" then return acc end
  acc = acc or { prompt = 0, completion = 0, total = 0, calls = 0 }
  local p = tonumber(usage.prompt_tokens) or 0
  local c = tonumber(usage.completion_tokens) or 0
  acc.prompt = acc.prompt + p
  acc.completion = acc.completion + c
  acc.total = acc.total + (tonumber(usage.total_tokens) or (p + c))
  acc.calls = acc.calls + 1
  return acc
end

return M
