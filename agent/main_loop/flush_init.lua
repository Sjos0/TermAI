-- flush_init.lua — calcula o índice inicial de mensagens novas para o flush.
-- Sessão com índice salvo continua de onde parou; legado limita às últimas 15;
-- sessão vazia começa após o fim da lista atual.
-- Interface: M.compute(ctx) → number
local session = require("session")

local M = {}

function M.compute(ctx)
  local saved_idx = session.get_flush_index and session.get_flush_index() or nil
  if saved_idx then
    return saved_idx + 1
  end
  if #ctx.msgs > 0 then
    -- Legado: evita "Sandbox Blowout" processando só as últimas 15.
    return math.max(1, #ctx.msgs - 15)
  end
  return #ctx.msgs + 1
end

return M
