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
    "High-performance recursive content search to locate references, function definitions, variables, classes, specific code snippets, or terms across multiple files.\n"
    .. "ALWAYS use this when you need to scan the project to map where something is implemented. It is hundreds of times faster and saves over 95% of tokens compared to reading files sequentially or listing directories.\n"
    .. "Automatically ignores hidden data/control folders (.git, .TermAI) and binary files.",
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
          description = "Search pattern (accepts Lua Patterns, the native equivalent of regex). Ex: 'function M%..*' or 'class %w+'."
        },
        path = {
          type = "string",
          description = "Starting path or directory for recursive search. Default: project root directory."
        },
        include = {
          type = "string",
          description = "Optional file filter based on simple glob matching. Ex: '*.py', '*.json', '*.lua', '*.md'."
        }
      },
      required = {"pattern"}
    }
  )
end

return M
