-- tools/find.lua — Fachada da ferramenta "Find".
-- v3: Despacha para o módulo de domínio searcher.lua (sem usar init.lua).
local M = {}
local searcher = require("tools.find.searcher")

function M.register(tools_mod, helpers)
  tools_mod.register("Find",
    "Search for files by name (partial or complete) in the workspace (default) or in custom directories. "
    .. "Highly preferred over running raw shell commands (like 'exec find') as this tool is heavily optimized, sanitizes inputs, and avoids context window bloat.",
    function(arg)
      return searcher.run(arg, helpers)
    end,
    {
      type = "object",
      properties = {
        name = {
          type = "string",
          description = "File name to search for (partial or complete). Ex: 'store' or 'messages.lua'."
        },
        dir = {
          type = "string",
          description = "Optional directory path to search inside. Default: workspace. Ex: '~/TermAI/' or 'session/'."
        }
      },
      required = {"name"}
    }
  )
end

return M
