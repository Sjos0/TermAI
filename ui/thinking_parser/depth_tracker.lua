local constants  = require("ui.thinking_parser.constants")

local OPEN_TOOL  = constants.OPEN_TOOL
local CLOSE_TOOL = constants.CLOSE_TOOL

local M = {}

-- Estado interno do depth_tracker para viabilizar escaneamento incremental O(N).
-- Optimization (Bolt): Caching de profundidade e índice do último escaneamento.
-- Isso evita complexidade O(N^2) ao re-escanear o buffer completo em cada token.
local state_depth = 1
local state_j     = 1

function M.reset()
  state_depth = 1
  state_j     = 1
end

-- Busca o </tool> que fecha o bloco EXTERNO rastreando profundidade.
-- _buf ja nao tem o <tool> de abertura (consumido ao entrar em tool mode).
-- depth=1 = estamos dentro do bloco cujo <tool> ja foi emitido.
-- Retorna a posicao do </tool> correspondente, ou nil se ainda nao chegou.
function M.find_matching_close(buf)
  local depth = state_depth
  local j     = state_j
  while j <= #buf do
    local open_s  = buf:find(OPEN_TOOL,  j, true)
    local close_s = buf:find(CLOSE_TOOL, j, true)

    if not close_s then
      -- </tool> não encontrado na parte restante do buffer.
      -- Salvamos o estado atual de profundidade e o índice `j` para continuar depois.
      state_depth = depth
      state_j     = j
      return nil
    end

    if open_s and open_s < close_s then
      depth = depth + 1
      j     = open_s + #OPEN_TOOL
    else
      depth = depth - 1
      if depth == 0 then
        -- Encontramos o fechamento correspondente do bloco externo.
        -- Resetamos o estado para o próximo bloco de ferramenta.
        M.reset()
        return close_s
      end
      j     = close_s + #CLOSE_TOOL
    end
  end

  state_depth = depth
  state_j     = j
  return nil
end

return M
