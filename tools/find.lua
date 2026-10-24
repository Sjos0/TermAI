-- tools/find.lua — Fachada da ferramenta "Find".
-- v3: Despacha para o módulo de domínio searcher.lua (sem usar init.lua).
local M = {}
local searcher = require("tools.find.searcher")

function M.register(tools_mod, helpers)
  tools_mod.register("Find",
    [==[Find files by name, partial or complete, inside the workspace or a directory you choose. Use it when you know part of a file name and need its path. Do not use it to search file contents (use Grep) or to list a folder's structure (use List). Examples: name 'store' to find every file whose name contains 'store', or name 'messages.lua' with dir 'session/'.]==],
    function(arg)
      return searcher.run(arg, helpers)
    end,
    {
      type = "object",
      properties = {
        name = {
          type = "string",
          description = "File name to find, partial or complete. Examples: 'store' or 'messages.lua'."
        },
        dir = {
          type = "string",
          description = "Directory to search inside. Default: the workspace. Examples: '~/TermAI/' or 'session/'."
        }
      },
      required = {"name"}
    }
  )
end

return M
