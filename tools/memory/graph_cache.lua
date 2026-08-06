-- graph_cache.lua — Persistência em disco do grafo de memória entre reinícios
-- do processo. O cache em RAM de tools/memory.lua só sobrevive dentro do mesmo
-- processo; este módulo evita que CADA boot/restart reprocesse (regex de tags +
-- snippets) o histórico inteiro de memória — só o que mudou desde o último save.
local json     = require("json")
local io_utils = require("tools.memory.io_utils")

local M = {}
M.CACHE_PATH = io_utils.MEMORY_DIR .. "/.graph_cache.json"

-- Carrega as entradas cacheadas (path -> {size, date, file, tags, snippets}).
-- Retorna nil se não existir ou estiver corrompido — nunca derruba o boot.
function M.load()
  local f = io.open(M.CACHE_PATH, "r")
  if not f then return nil end
  local raw = f:read("*a")
  f:close()
  if not raw or raw == "" then return nil end

  local ok, data = pcall(json.decode, raw)
  if not ok or type(data) ~= "table" then return nil end
  if data.version ~= 1 or type(data.entries) ~= "table" then return nil end
  return data.entries
end

-- Salva as entradas no disco. Melhor-esforço: falha silenciosa, nunca quebra o boot.
function M.save(entries)
  local ok, encoded = pcall(json.encode, { version = 1, entries = entries })
  if not ok then return false end

  os.execute('mkdir -p "' .. io_utils.MEMORY_DIR .. '" 2>/dev/null')
  local f = io.open(M.CACHE_PATH, "w")
  if not f then return false end
  f:write(encoded)
  f:close()
  return true
end

return M
