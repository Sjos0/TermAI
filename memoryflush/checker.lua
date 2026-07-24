-- memoryflush/checker.lua — Verificação lógica de limites de flush e compactação.
local M = {}
local state_mod = require("memoryflush.state")

function M.deve_flush(tokens, config)
  if not config.limites then return false end
  if config.limites.flush_enabled == false then return false end
  local limite = config.limites.flush_tokens or 40000
  return (tokens - state_mod.get_ultimo(tokens)) >= limite
end

-- v2: reserve_tokens (estilo OpenClaw) dispara ANTES do limite estourar de
-- verdade, deixando headroom. compactacao_pct vira fallback pra janelas
-- pequenas onde a reserva sozinha nunca dispararia (reserve > janela).
function M.deve_compactar(tokens, config)
  if not config.limites then return false end
  local reserva = config.limites.reserve_tokens or 16384
  local pct     = config.limites.compactacao_pct or 0.90

  -- Evita underflow se max_contexto for menor que a reserva configurada
  local por_reserva = false
  if config.max_contexto and config.max_contexto > reserva then
    por_reserva = tokens >= (config.max_contexto - reserva)
  end

  local por_pct = false
  if config.max_contexto then
    por_pct = tokens >= (config.max_contexto * pct)
  end

  return por_reserva or por_pct
end

function M.proximo_flush(tokens, config)
  local limite = (config.limites and config.limites.flush_tokens) or 40000
  local ultimo = state_mod.get_ultimo(tokens)

  -- Se já estourou ou está na hora do flush, o próximo passo conta a partir de agora
  if (tokens - ultimo) >= limite then
    return tokens + limite
  else
    -- Caso contrário, projeta somando o limite dinâmico ao último marco salvo
    return ultimo + limite
  end
end

return M
