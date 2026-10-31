-- tools/restart.lua — Tool de reinício agendado.
-- v2: schema JSON para native tool calling.
local M = {}

function M.register(tools)
  tools.register("restart",
    [==[Schedule a restart of TermAI after the current reply. The context is saved before the restart. Use it only when the user asks for a restart, or when a configuration change requires one. Takes no arguments. The restart does not happen immediately, and the current reply is completed first. Do not use it to recover from an error; report the error to the user instead.]==],
    function()
      local restart_mod = require("agent.restart")
      if restart_mod.request() then
        return "[RESTART] Reinício agendado. O sistema reiniciará após o salvamento do contexto."
      else
        return "[FAIL] Erro ao agendar reinício."
      end
    end,
    {type = "object", properties = {}}
  )
end

return M
