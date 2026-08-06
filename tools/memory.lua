-- tools/memory.lua — Fachada + Orquestrador do motor GraphRAG Local.
-- v2: schema JSON para native tool calling + arg backward compat.
local io_utils      = require("tools.memory.io_utils")
local graph_builder = require("tools.memory.graph_builder")
local graph_cache   = require("tools.memory.graph_cache")
local search_engine = require("tools.memory.search_engine")

local memory = {}
local _cache = {graph = nil, file_count = 0}

local function get_graph()
  local files = io_utils.list_md_files(io_utils.MEMORY_DIR)
  if _cache.graph == nil or _cache.file_count ~= #files then
    local disk_entries = graph_cache.load()
    local graph, entries_out = graph_builder.build_graph(files, disk_entries)
    graph_cache.save(entries_out)

    _cache.graph      = graph
    _cache.file_count = #files
  end
  return _cache.graph, files
end

function memory.search(query)
  if not query or query:match("^%s*$") then
    return "❌ memory_search: forneça uma query. Ex: 'erros em Lua' ou 'decisões de arquitetura'."
  end
  local graph, files = get_graph()
  if #files == 0 then
    return "📭 Nenhum arquivo de memória encontrado em: " .. io_utils.MEMORY_DIR
      .. "\n💡 Dica: o Memory Flush cria arquivos YYYY-MM-DD.md automaticamente."
  end
  return search_engine.search(query, graph, files)
end

function memory.invalidate_cache()
  _cache.graph      = nil
  _cache.file_count = 0
end

function memory.register(tools)
  tools.register(
    "memory_search",
    "Memória pessoal e histórica (GraphRAG local). "
    .. "OBRIGATÓRIO antes de responder sobre: pessoas, eventos, decisões, "
    .. "bugs resolvidos ou qualquer dado histórico/pessoal. "
    .. "Já injetada automaticamente no contexto — use manualmente para refinar. "
    .. "'Não sei' sem busca prévia = erro de protocolo. "
    .. "Arg: query em linguagem natural.",
    function(arg)
      local q = type(arg) == "table" and (arg.query or arg.arg or "") or arg
      return memory.search(q)
    end,
    {
      type = "object",
      properties = {
        query = {
          type = "string",
          description = "Query em linguagem natural. Ex: 'quem é Alice', 'bug no parser X', 'decisão sobre Y em maio'."
        }
      },
      required = {"query"}
    }
  )
end

return memory
