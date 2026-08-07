-- tools/memory.lua — Fachada + Orquestrador do motor GraphRAG Local.
-- v3.3: cache v3 sem index no disco (JSON leve) + dirty flag + rebuild_index.
local io_utils      = require("tools.memory.io_utils")
local graph_builder = require("tools.memory.graph_builder")
local graph_cache   = require("tools.memory.graph_cache")
local tag_parser    = require("tools.memory.tag_parser")
local search_engine = require("tools.memory.search_engine")

local memory = {}
local _cache = { graph = nil, file_count = 0, file_hashes = nil, dirty = false }

local function ensure_content(graph)
  for path, node in pairs(graph.nodes) do
    if not node.content then
      local content = io_utils.read_file(path)
      node.content = content or ""
    end
  end
end

-- Reconstrói índice invertido em RAM (cache v3 não serializa index).
local function rebuild_index(graph)
  graph.index = {}
  for path, node in pairs(graph.nodes) do
    local content = node.content or ""
    local lower   = content:lower()
    for _, tag in ipairs(node.tags or {}) do
      if not graph.index[tag] then graph.index[tag] = {} end
      local snippet = content ~= "" and tag_parser.get_snippet(content, tag, nil, lower) or ""
      graph.index[tag][#graph.index[tag] + 1] = {
        file = node.file, path = path, date = node.date, snippet = snippet,
      }
    end
  end
end

local function get_graph()
  local files = io_utils.list_md_files(io_utils.MEMORY_DIR)

  if _cache.graph and _cache.file_count == #files and not _cache.dirty then
    return _cache.graph, files
  end

  local disk = graph_cache.load()
  local graph, file_hashes

  if disk and disk.version == graph_cache.VERSION then
    graph       = disk.graph
    file_hashes = disk.file_hashes or {}

    local disk_count = 0
    for _ in pairs(graph.nodes or {}) do disk_count = disk_count + 1 end

    if disk_count == #files and not _cache.dirty then
      ensure_content(graph)
      rebuild_index(graph)
      _cache.graph = graph; _cache.file_count = #files; _cache.file_hashes = file_hashes
      return graph, files
    end

    local current_set, changed = {}, {}
    for _, f in ipairs(files) do
      current_set[f] = true
      local mtime = graph_builder.get_mtime(f)
      if not file_hashes[f] or file_hashes[f] ~= mtime then
        changed[#changed + 1] = f
      end
    end
    for path in pairs(graph.nodes) do
      if not current_set[path] then
        graph_builder.remove_graph_node(graph, path)
        file_hashes[path] = nil
      end
    end
    for _, f in ipairs(changed) do
      if graph_builder.update_graph_node(graph, f) then
        file_hashes[f] = graph_builder.get_mtime(f)
      else
        file_hashes[f] = nil
      end
    end
    ensure_content(graph)
    rebuild_index(graph)
    graph_cache.save(graph, file_hashes)
    _cache.dirty = false
  else
    graph, file_hashes = graph_builder.build_graph_full(files)
    graph_cache.save(graph, file_hashes)
    _cache.dirty = false
  end

  _cache.graph = graph; _cache.file_count = #files; _cache.file_hashes = file_hashes
  return graph, files
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

function memory.invalidate_cache(also_disk)
  _cache.graph = nil; _cache.file_count = 0; _cache.file_hashes = nil; _cache.dirty = true
  if also_disk then pcall(os.remove, graph_cache.CACHE_PATH) end
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
        query = { type = "string", description = "Query em linguagem natural." }
      },
      required = {"query"}
    }
  )
end

return memory
