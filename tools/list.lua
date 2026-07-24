-- tools/list.lua — Fachada da ferramenta "List".
-- v3: Despacha para o módulo de domínio lister.lua (sem usar init.lua).
local M = {}
local lister = require("tools.list.lister")

function M.register(tools_mod, helpers)
  tools_mod.register("List",
    "List the contents of the workspace (default) or custom directories up to 3 levels deep.",
    function(arg)
      return lister.run(arg, helpers)
    end,
    {
      type = "object",
      properties = {
        dir = {
          type = "string",
          description = "Optional directory path to list. Default: workspace. Ex: '~/TermAI/' or 'session/'."
        }
      }
    }
  )
end

return M
