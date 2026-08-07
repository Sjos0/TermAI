-- graph_cache.lua — Persistência em disco do grafo de memória.
-- v3: NÃO salva index (snippets inflavam JSON a 12MB).
--     Salva só nodes (metadata) + edges + file_hashes.
--     Index é reconstruído em RAM após ensure_content.
local json     = require("json")
local io_utils = require("tools.memory.io_utils")

local M = {}
M.CACHE_PATH = io_utils.MEMORY_DIR .. "/.graph_cache.json"
M.VERSION    = 3

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
  if type(data.graph.nodes) ~= "table" or type(data.graph.edges) ~= "table" then
    return nil
  end

  data.graph.index = data.graph.index or {}
  return data
end

function M.save(graph, file_hashes)
  if type(graph) ~= "table" or type(file_hashes) ~= "table" then
    return false
  end

  local slim_nodes = {}
  for path, node in pairs(graph.nodes or {}) do
    slim_nodes[path] = {
      date = node.date,
      tags = node.tags,
      file = node.file,
    }
  end

  local payload = {
    version     = M.VERSION,
    file_hashes = file_hashes,
    graph       = {
      nodes = slim_nodes,
      edges = graph.edges or {},
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
