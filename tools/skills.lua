-- tools/skills.lua — Fachada do sistema de Skills.
-- v2: schema JSON para native tool calling + arg backward compat.
local engine = require("tools.skills.init")
local M = {}

M.current_agent = "main"

function M.register(tools)
  tools.register("skill",
    [==[Load a specialised skill by its folder name and follow its instructions. Use it when the skill's description in the catalog matches the user's task. Do not load a skill speculatively. Pass the folder name exactly as it appears in the catalog. Example: name 'debug-methodology'.]==],
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
          description = "Skill name: the folder name, for example 'debug-methodology' or 'lua-programming'."
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
