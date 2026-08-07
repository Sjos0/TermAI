-- tools/memory.lua — Fachada + Orquestrador do motor GraphRAG Local.
-- v3: cache de grafo completo + atualização incremental (Spec 2026-08-06).
local io_utils      = require("tools.memory.io_utils")
local graph_builder = require("tools.memory.graph_builder")
local graph_cache   = require("tools.memory.graph_cache")
local search_engine = require("tools.memory.search_engine")

local memory = {}
local _cache = { graph = nil, file_count = 0 }

-- Retorna o grafo (com atualização incremental se necessário).
local function get_graph()
  local files = io_utils.list_md_files(io_utils.MEMORY_DIR)

  -- Cache em RAM ainda válido e mesma quantidade de arquivos?
  if _cache.graph and _cache.file_count == #files then
    return _cache.graph, files
  end

  local disk = graph_cache.load()
  local graph, file_hashes

  if disk and disk.version == graph_cache.VERSION then
    -- ── Caminho quente: verificar mudanças por mtime ──────────────────────
    graph       = disk.graph
    file_hashes = disk.file_hashes or {}

    local current_set = {}
    local changed = {}

    for _, f in ipairs(files) do
      current_set[f] = true
      local mtime = graph_builder.get_mtime(f)
      if not file_hashes[f] or file_hashes[f] ~= mtime then
        changed[#changed + 1] = f
      end
    end

    -- Arquivos removidos
    for path in pairs(graph.nodes) do
      if not current_set[path] then
        graph_builder.remove_graph_node(graph, path)
        file_hashes[path] = nil
      end
    end

    -- Arquivos novos ou modificados
    for _, f in ipairs(changed) do
      if graph_builder.update_graph_node(graph, f) then
        file_hashes[f] = graph_builder.get_mtime(f)
      else
        file_hashes[f] = nil
      end
    end

    -- Persistência (melhor-esforço)
    if #changed > 0 or next(file_hashes) then
      graph_cache.save(graph, file_hashes)
    end
  else
    -- ── Caminho frio: rebuild completo ────────────────────────────────────
    graph, file_hashes = graph_builder.build_graph_full(files)
    graph_cache.save(graph, file_hashes)
  end

  _cache.graph      = graph
  _cache.file_count = #files
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

function memory.invalidate_cache()
  _cache.graph      = nil
  _cache.file_count = 0
  -- Também remove o cache em disco para forçar rebuild no próximo acesso
  pcall(os.remove, graph_cache.CACHE_PATH)
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
