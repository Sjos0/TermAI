-- commands_router.lua — Sub-fachada: roteamento de comandos (Bloco 4).
-- Ordem de verificação preservada do original: /commands → lifecycle.* →
-- simple.*. /commands pode reatribuir `input` e cair nas verificações
-- seguintes DENTRO DA MESMA CHAMADA — essa cascata é intencional.
-- lifecycle e simple cobrem conjuntos de comandos mutuamente exclusivos
-- (prefixos/igualdades distintas), então a ordem entre os dois grupos não
-- afeta qual comando casa; apenas a ordem DENTRO de cada grupo importa.
local commands_menu = require("commands.commands")
local simple    = require("agent.main_loop.commands_router.simple")
local lifecycle = require("agent.main_loop.commands_router.lifecycle")
local M = {}

local function route(input, ctx, flush_msgs_start)
  -- /commands: menu interativo pode trocar `input` por outro comando, que é
  -- então re-verificado pelos roteadores abaixo na mesma chamada.
  if input == "/commands" then
    local selected = commands_menu.run()
    if selected and selected ~= "/commands" then
      input = selected
    else
      return { input = input, action = "continue" }
    end
  end

  local lc = lifecycle.route(input, ctx, flush_msgs_start)
  if lc.action then
    return {
      input            = input,
      flush_msgs_start = lc.flush_msgs_start or flush_msgs_start,
      action           = lc.action,
    }
  end

  local sm = simple.route(input, ctx, flush_msgs_start)
  if sm.action then
    return {
      input            = input,
      flush_msgs_start = sm.flush_msgs_start or flush_msgs_start,
      action           = sm.action,
    }
  end

  -- Nenhum comando correspondeu: segue para o input normal (bloco 5)
  -- com `input` (possivelmente substituído por /commands).
  return { input = input, flush_msgs_start = flush_msgs_start }
end

M.route = route
return M
