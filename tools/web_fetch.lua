-- tools/web_fetch.lua — Fachada da ferramenta "web_fetch".
-- v1: Despacha para o módulo de domínio fetcher.lua (sem usar init.lua).
local M = {}
local fetcher = require("tools.web_fetch.fetcher")

function M.register(tools_mod, helpers)
  tools_mod.register("web_fetch",
    [==[Fetch one web page by URL and return its readable text or markdown. Use it only when you already have the exact URL, for example from web_search results or from the user. Do not use it for open-ended searches (use web_search). The output is limited to maxChars characters (default 8000) to protect the context window. Example: url 'https://lua.org'.]==],
    function(arg)
      return fetcher.run(arg)
    end,
    {
      type = "object",
      properties = {
        url = {
          type = "string",
          description = "HTTP or HTTPS URL to fetch. E.g. 'https://lua.org' or 'https://en.wikipedia.org/wiki/Lua'."
        },
        extractMode = {
          type = "string",
          description = "Extraction mode: 'markdown' or 'text'. Default: 'markdown'."
        },
        maxChars = {
          type = "number",
          description = "Maximum characters to return (to prevent context window bloat). Default is 8000."
        }
      },
      required = {"url"}
    }
  )
end

return M
