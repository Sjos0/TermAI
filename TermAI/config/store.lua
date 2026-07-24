local json = require("json")
local M = {}

local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
M.PATH = HOME .. "/.TermAI/config.json"
M._data = nil

function M.load()
  local f = io.open(M.PATH, "r")
  if not f then
    print("[ERRO] config.json não encontrado em " .. M.PATH)
    os.exit(1)
  end
  local content = f:read("*a")
  f:close()

  local ok, data = pcall(json.decode, content)
  if not ok then
    print("[ERRO] config.json inválido!")
    os.exit(1)
  end

  local needs_save = false
  if data.modelo then
    local migrate = require("config.migrate")
    data = migrate.run(data)
    needs_save = true
  end

  M._data = data
  if needs_save then M.save() end
  return M._data
end

function M.save()
  if not M._data then return false end
  M._data.meta = M._data.meta or {}
  M._data.meta.lastTouchedAt = os.date("!%Y-%m-%dT%H:%M:%S.000Z")
  local f = io.open(M.PATH, "w")
  if not f then return false end
  f:write(json.encode(M._data))
  f:close()
  return true
end

function M.data()
  if not M._data then M.load() end
  return M._data
end

return M
