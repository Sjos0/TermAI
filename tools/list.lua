-- tools/list.lua — Fachada da ferramenta "List".
-- v3: Despacha para o módulo de domínio lister.lua (sem usar init.lua).
local M = {}
local lister = require("tools.list.lister")

function M.register(tools_mod, helpers)
  tools_mod.register("List",
    [==[List the entries of a directory up to three levels deep. Use it to understand a folder's structure before reading or searching. Do not use it to find a file by name (use Find) or to read file contents (use Read). The default directory is the workspace. Example: dir '~/TermAI/'.]==],
    function(arg)
      return lister.run(arg, helpers)
    end,
    {
      type = "object",
      properties = {
        dir = {
          type = "string",
          description = "Directory to list. Default: the workspace. Examples: '~/TermAI/' or 'session/'."
        }
      }
    }
  )
end

return M
