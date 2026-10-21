-- tools/subagents.lua — Fachada: sessions_spawn cria um clone efêmero do agente atual.
local spawn = require("tools.subagents.spawn")

local M = {}
local bound_ctx = nil

-- Guarda o contexto do agente que está rodando o turno (chamado por agent/loop).
function M.bind(ctx) bound_ctx = ctx end

-- Devolve o contexto do agente ativo para quem precisa criar um clone.
function M.current() return bound_ctx end

function M.register(tools)
  tools.register(
    "sessions_spawn",
    "Cria um clone temporário deste agente para executar uma tarefa isolada. "
      .. "O clone roda até o fim, a resposta final volta como resultado e a sessão dele é descartada. "
      .. "Clones rodam um de cada vez e não podem criar outro clone.",
    function(arg)
      local args = type(arg) == "table" and arg or { task = tostring(arg or "") }
      return spawn.spawn(args, bound_ctx)
    end,
    {
      type = "object",
      properties = {
        task = { type = "string", description = "Tarefa que o clone deve executar (obrigatório)." },
      },
      required = { "task" },
    }
  )
end

return M
