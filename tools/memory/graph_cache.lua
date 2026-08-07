-- graph_cache.lua — Persistência em disco do GRAFO COMPLETO de memória.
-- v2: salva nós + arestas + índice invertido + file_hashes (mtime).
-- No boot com cache quente, zero leitura de .md — só JSON decode.
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

  -- Integridade mínima do grafo
  if type(data.graph.index) ~= "table"
     or type(data.graph.nodes) ~= "table"
     or type(data.graph.edges) ~= "table" then
    return nil
  end

  return data
end

-- Salva o grafo completo + hashes. Melhor-esforço: falha silenciosa.
function M.save(graph, file_hashes)
  if type(graph) ~= "table" or type(file_hashes) ~= "table" then
    return false
  end

  local payload = {
    version     = M.VERSION,
    file_hashes = file_hashes,
    graph       = graph,
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
