-- tools/skills.lua — Fachada do sistema de Skills.
-- v2: schema JSON para native tool calling + arg backward compat.
local engine = require("tools.skills.init")
local M = {}

M.current_agent = "main"

function M.register(tools)
  tools.register("skill",
    "Carrega uma skill especializada pelo nome. Use quando a descrição da skill "
    .. "no catálogo se alinha com a tarefa do usuário. "
    .. "Arg: nome da pasta da skill.",
    function(arg)
      local skill_name = type(arg) == "table" and (arg.name or arg.arg or "") or arg
      local agent_name = M.current_agent or "main"
      return engine.execute_skill(skill_name, agent_name)
    end,
    {
      type = "object",
      properties = {
        name = {
          type = "string",
          description = "Nome da skill (nome da pasta, ex: 'debug-methodology', 'lua-programming')"
        }
      },
      required = {"name"}
    }
  )
end

function M.build_catalog(agent_name)
  return engine.build_catalog(agent_name or M.current_agent)
end

return M
