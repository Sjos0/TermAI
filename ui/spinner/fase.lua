-- ui/spinner/fase.lua — Máquina de estados do rótulo do spinner (Injetando → Requisitando → Trabalhando).
-- Função pura: cada evento devolve o próximo estado. Eventos fora de ordem são ignorados.
-- Regra: dentro do turno do agente o rótulo fica em "trabalhando" até o turno terminar,
-- mesmo com várias tools e respostas parciais. Só turn_end volta ao ocioso.
local M = {}

local LABEL = {
  injetando    = "Injetando",
  requisitando = "Requisitando",
  trabalhando  = "Trabalhando",
}

local NEXT = {
  idle         = { user_send = "injetando" },
  injetando    = { inject_done = "requisitando" },
  requisitando = { agent_turn = "trabalhando" },
  trabalhando  = { turn_end = "idle" },
}

function M.new()
  return "idle"
end

-- Próximo estado para o evento. Se o evento não se aplica, permanece no estado atual.
function M.on(state, event)
  local row = NEXT[state]
  return (row and row[event]) or state
end

-- Texto do rótulo para o estado; nil quando ocioso (sem spinner).
function M.label(state)
  return LABEL[state]
end

return M
