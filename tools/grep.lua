-- tools/grep.lua — Facade para a ferramenta standalone "Grep"
local searcher  = require("tools.grep.searcher")
local formatter = require("tools.grep.formatter")
local M = {}

function M.register(tools, helpers)
  local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
  local BASE = HOME .. "/TermAI"
  local expand = helpers.expand_path

  -- Resolve caminho: absoluto usa direto, relativo resolve a partir do TermAI base
  local function resolve_grep_path(p)
    if not p or p == "" then return BASE .. "/workspace" end
    if p:match("^/") or p:match("^~/") then return expand(p) end
    -- Relativo: resolve a partir da raiz do TermAI
    return BASE .. "/" .. p:gsub("^%./", "")
  end

  tools.register("Grep",
    [==[Search file contents for a Lua pattern across a directory tree and return each matching line with its file and line number. Use it to find where a function, variable, class or phrase is defined or used, before opening files. Do not use it to find files by name (use Find) or to read a whole file (use Read). Patterns are Lua patterns, not regular expressions: '|' is a literal character, so use %d and %w instead of \d and \w, and escape magic characters with %. Binary files, .git and sensitive files (config.json, tokens, keys) are skipped. Results stop at 100 matches. Example: pattern 'function M%.' with include '*.lua'.]==],
    function(arg)
      local opts = {}
      if type(arg) == "table" then
        opts.pattern = arg.pattern or ""
        opts.path = arg.path and resolve_grep_path(arg.path) or nil
        opts.include = arg.include
      else
        -- Suporte para argumento simples de string legado (apenas o padrão)
        opts.pattern = arg or ""
        opts.path = nil  -- searcher usa BASE por padrão
      end

      if not opts.pattern or opts.pattern == "" then
        return "❌ Erro: O parâmetro 'pattern' é obrigatório."
      end

      local res, err = searcher.execute(opts)
      if err then
        return "❌ Erro na busca: " .. tostring(err)
      end

      return formatter.format(res, opts.pattern)
    end,
    -- Schema JSON formato OpenAI
    {
      type = "object",
      properties = {
        pattern = {
          type = "string",
          description = "Lua pattern, not a regular expression: '|' is literal, so use %d and %w instead of \\d and \\w, and escape magic characters with %. Example: 'function M%.' or 'class %w+'."
        },
        path = {
          type = "string",
          description = "Directory to search recursively. Default: the workspace."
        },
        include = {
          type = "string",
          description = "Optional glob filter on file names, for example '*.lua' or '*.md'. Only matching files are searched."
        }
      },
      required = {"pattern"}
    }
  )
end

return M
