-- tools/agents.lua — Fachada: agents_create cria agentes independentes com workspace próprio.
local create = require("tools.agents.create")

local M = {}

function M.register(tools)
  tools.register(
    "agents_create",
    "Cria um agente independente com workspace próprio. ANTES de chamar, pergunte ao usuário "
      .. "o id, o nome, a identidade e as funções do agente. Só então envie confirmado=true. "
      .. "O USER.md do usuário é copiado automaticamente.",
    function(arg)
      return create.create(type(arg) == "table" and arg or {})
    end,
    {
      type = "object",
      properties = {
        id         = { type = "string", description = "Identificador curto: minúsculas, números, _ ou -." },
        nome       = { type = "string", description = "Nome do agente (vai para IDENTITY.md)." },
        identidade = { type = "string", description = "Quem é o agente e como fala (IDENTITY.md)." },
        funcoes    = { type = "string", description = "O que o agente faz e as regras de trabalho (AGENTS.md)." },
        confirmado = { type = "boolean", description = "true só depois que o usuário confirmar." },
      },
      required = { "id", "identidade", "funcoes", "confirmado" },
    }
  )
end

return M
