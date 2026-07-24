-- tools/web_fetch.lua — Fachada da ferramenta "web_fetch".
-- v1: Despacha para o módulo de domínio fetcher.lua (sem usar init.lua).
local M = {}
local fetcher = require("tools.web_fetch.fetcher")

function M.register(tools_mod, helpers)
  tools_mod.register("web_fetch",
    "Fetch and extract clean, readable text or content from a specific HTTP or HTTPS URL. Use ONLY when you already have a specific URL to read. For general web searches, use 'pesquisar_web' instead.",
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
