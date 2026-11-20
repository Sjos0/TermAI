local json = require("json")
local M = {}

local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
M.PATH = HOME .. "/.TermAI/agents/main/agent/models.json"
M._data = nil

local function normalize_provider(provider)
  local source = provider.apiKeys
  local changed = false
  if type(source) ~= "table" or (#source == 0 and type(provider.apiKey) == "string"
      and provider.apiKey ~= "") then
    source = {}
    if type(provider.apiKey) == "string" and provider.apiKey ~= "" then
      source[1] = provider.apiKey
    end
    changed = true
  end

  local keys, seen = {}, {}
  for _, entry in ipairs(source) do
    local key = type(entry) == "table" and entry.key or entry
    if type(key) == "string" and key ~= "" and not seen[key] then
      seen[key] = true
      local item = type(entry) == "table" and entry or { key = key }
      if item.key ~= key then item.key = key; changed = true end
      keys[#keys + 1] = item
    else
      changed = true
    end
  end
  if #keys ~= #source then changed = true end
  provider.apiKeys = keys

  local active = tonumber(provider.activeKeyIndex) or 1
  if active < 1 or active > #keys then active = 1; changed = true end
  provider.activeKeyIndex = active
  local active_key = keys[active] and keys[active].key or ""
  if provider.apiKey ~= active_key then provider.apiKey = active_key; changed = true end
  return changed
end

local function normalize_data(data)
  local changed = false
  data.providers = type(data.providers) == "table" and data.providers or {}
  for _, provider in pairs(data.providers) do
    if type(provider) == "table" and normalize_provider(provider) then
      changed = true
    end
  end
  return changed
end

local function ensure_dir()
  local dir = M.PATH:match("^(.*)/[^/]+$")
  if dir then os.execute("mkdir -p '" .. dir .. "'") end
end

function M.load()
  local f = io.open(M.PATH, "r")
  if not f then
    M._data = { active = "", providers = {} }
    return M._data
  end
  local ok, data = pcall(json.decode, f:read("*a"))
  f:close()
  if not ok or type(data) ~= "table" then
    M._data = { active = "", providers = {} }
    return M._data
  end
  M._data = data
  if normalize_data(M._data) then M.save() end
  return M._data
end

function M.save()
  if not M._data then return false end
  normalize_data(M._data)
  ensure_dir()
  local unique = os.tmpname()
  local suffix = unique:match("([^/]+)$") or tostring(os.time())
  os.remove(unique)
  local tmp_path = M.PATH .. ".tmp." .. suffix
  local f = io.open(tmp_path, "w")
  if not f then return false end
  f:write(json.encode(M._data))
  f:close()
  local ok = os.rename(tmp_path, M.PATH)
  if not ok then os.remove(tmp_path); return false end
  return true
end

function M.data()
  if not M._data then M.load() end
  return M._data
end

function M.normalize_provider(provider)
  if type(provider) ~= "table" then return false end
  return normalize_provider(provider)
end

return M
