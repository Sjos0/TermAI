-- tools/agents.lua — Fachada: agents_create cria agentes independentes com workspace próprio.
local create = require("tools.agents.create")

local M = {}

function M.register(tools)
  tools.register(
    "agents_create",
    [==[Create an independent agent with its own workspace, identity and rules. Use it only when the user asks for a new independent agent. Do not use it for a subagent of the current task; use sessions_spawn for that. Before calling it, ask the user for the id, name, identity and functions. Call it again with confirmed set to true only after the user has agreed to those details. The user's USER.md is copied automatically. Ids use lowercase letters, digits, '_' or '-' (2 to 32 characters); 'main' is reserved.]==],
    function(arg)
      return create.create(type(arg) == "table" and arg or {})
    end,
    {
      type = "object",
      properties = {
        id         = { type = "string", description = "Short id: lowercase letters, digits, '_' or '-' (2 to 32 characters)." },
        nome       = { type = "string", description = "Agent display name, written to IDENTITY.md." },
        identidade = { type = "string", description = "Who the agent is and how it speaks (IDENTITY.md)." },
        funcoes    = { type = "string", description = "What the agent does and its working rules (AGENTS.md)." },
        confirmado = { type = "boolean", description = "Set to true only after the user has confirmed the details." },
      },
      required = { "id", "identidade", "funcoes", "confirmado" },
    }
  )
end

return M
