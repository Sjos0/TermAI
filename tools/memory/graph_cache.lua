-- graph_cache.lua — Persistência em disco do GRAFO COMPLETO de memória.
-- v2.1: grafo completo SEM content (só metadata) + file_hashes (mtime).
-- Boot quente = JSON decode leve + zero leitura de .md.
local json     = require("json")
local io_utils = require("tools.memory.io_utils")

local M = {}
M.CACHE_PATH = io_utils.MEMORY_DIR .. "/.graph_cache.json"
M.VERSION    = 2

-- Carrega o cache completo. Retorna nil em qualquer falha (nunca derruba o boot).
function M.load()
  local f = io.open(M.CACHE_PATH, "r")
  if not f then return nil end
  local raw = f:read("*a")
  f:close()
  if not raw or raw == "" then return nil end

  local ok, data = pcall(json.decode, raw)
  if not ok or type(data) ~= "table" then return nil end
  if data.version ~= M.VERSION then return nil end
  if type(data.graph) ~= "table" then return nil end
  if type(data.file_hashes) ~= "table" then return nil end

  if type(data.graph.index) ~= "table"
     or type(data.graph.nodes) ~= "table"
     or type(data.graph.edges) ~= "table" then
    return nil
  end

  return data
end

-- Salva o grafo (sem content) + hashes. Melhor-esforço.
function M.save(graph, file_hashes)
  if type(graph) ~= "table" or type(file_hashes) ~= "table" then
    return false
  end

  -- Strip content before serializing (search_engine lê do disco sob demanda)
  local slim_nodes = {}
  for path, node in pairs(graph.nodes or {}) do
    slim_nodes[path] = {
      date = node.date,
      tags = node.tags,
      file = node.file,
      -- content propositalmente omitido
    }
  end

  local payload = {
    version     = M.VERSION,
    file_hashes = file_hashes,
    graph       = {
      index = graph.index,
      nodes = slim_nodes,
      edges = graph.edges,
    },
  }

  local ok, encoded = pcall(json.encode, payload)
  if not ok then return false end

  os.execute('mkdir -p "' .. io_utils.MEMORY_DIR .. '" 2>/dev/null')
  local f = io.open(M.CACHE_PATH, "w")
  if not f then return false end
  f:write(encoded)
  f:close()
  return true
end

return M
