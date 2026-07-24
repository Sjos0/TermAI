local constants  = require("ui.thinking_parser.constants")

local OPEN_TOOL  = constants.OPEN_TOOL
local CLOSE_TOOL = constants.CLOSE_TOOL

local M = {}

-- Busca o </tool> que fecha o bloco EXTERNO rastreando profundidade.
-- _buf ja nao tem o <tool> de abertura (consumido ao entrar em tool mode).
-- depth=1 = estamos dentro do bloco cujo <tool> ja foi emitido.
-- Retorna a posicao do </tool> correspondente, ou nil se ainda nao chegou.
function M.find_matching_close(buf)
  local depth = 1
  local j = 1
  while j <= #buf do
    local open_s  = buf:find(OPEN_TOOL,  j, true)
    local close_s = buf:find(CLOSE_TOOL, j, true)
    if not close_s then return nil end
    if open_s and open_s < close_s then
      depth = depth + 1
      j = open_s + #OPEN_TOOL
    else
      depth = depth - 1
      if depth == 0 then return close_s end
      j = close_s + #CLOSE_TOOL
    end
  end
  return nil
end

return M
