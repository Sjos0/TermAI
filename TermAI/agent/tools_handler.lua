-- tools_handler.lua — Fachada
-- Interface publica inalterada: parsear(resp), executar(ferramentas), executar_silent(ferramentas)
-- Consumidores (loop.lua etc.) nao precisam mudar nada.
local handler = require("agent.tools_handler.init")
return handler
