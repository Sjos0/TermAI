-- tools/restart.lua — Tool de reinício agendado.
-- v2: schema JSON para native tool calling.
local M = {}

function M.register(tools)
  tools.register("restart",
    "Agenda o reinício do TermAI para após a resposta atual. O contexto é salvo antes do reinício.",
    function()
      local restart_mod = require("agent.restart")
      if restart_mod.request() then
        return "🔄 Reinício agendado. O sistema reiniciará após o salvamento do contexto."
      else
        return "❌ Erro ao agendar reinício."
      end
    end,
    {type = "object", properties = {}}
  )
end

return M
