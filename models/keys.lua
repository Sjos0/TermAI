local store = require("models.store")
local M = {}

local function provider_for(provider_id)
  return store.data().providers[provider_id]
end

local function normalize(provider)
  store.normalize_provider(provider)
  return provider.apiKeys, provider.activeKeyIndex
end

function M.list(provider_id)
  local provider = provider_for(provider_id)
  if not provider then return nil, "Provedor não encontrado" end
  local keys = normalize(provider)
  local result = {}
  for i, item in ipairs(keys) do
    result[i] = {
      index = i, key = item.key, last_ok = item.last_ok,
      last_error_at = item.last_error_at, active = i == provider.activeKeyIndex,
    }
  end
  return result
end

function M.active(provider_id)
  local provider = provider_for(provider_id)
  if not provider then return nil, nil, 0 end
  local keys, index = normalize(provider)
  local item = keys[index]
  return item and item.key or "", index, #keys
end

function M.add(provider_id, key)
  local provider = provider_for(provider_id)
  if not provider then return false, "Provedor não encontrado" end
  if type(key) ~= "string" or key:match("^%s*$") then
    return false, "API Key não pode ficar vazia"
  end
  local keys = normalize(provider)
  key = key:match("^%s*(.-)%s*$")
  local safe, invalid_char = require("agent.security").is_safe(key)
  if not safe then
    return false, "API Key contém caractere não permitido: " .. tostring(invalid_char)
  end
  for _, item in ipairs(keys) do
    if item.key == key then return false, "Esta API Key já está cadastrada" end
  end
  keys[#keys + 1] = { key = key }
  if #keys == 1 then provider.activeKeyIndex = 1 end
  provider.apiKey = keys[provider.activeKeyIndex].key
  return store.save()
end

function M.remove(provider_id, index)
  local provider = provider_for(provider_id)
  if not provider then return false, "Provedor não encontrado" end
  local keys = normalize(provider)
  index = tonumber(index)
  if not index or index % 1 ~= 0 or index < 1 or index > #keys then
    return false, "Índice de API Key inválido"
  end
  local previous_active = provider.activeKeyIndex
  table.remove(keys, index)
  if #keys == 0 then
    provider.activeKeyIndex, provider.apiKey = 1, ""
  else
    if index < previous_active then
      provider.activeKeyIndex = previous_active - 1
    elseif index == previous_active then
      provider.activeKeyIndex = math.min(index, #keys)
    end
    if provider.activeKeyIndex < 1 or provider.activeKeyIndex > #keys then
      provider.activeKeyIndex = 1
    end
    provider.apiKey = keys[provider.activeKeyIndex].key
  end
  return store.save()
end

function M.set_active(provider_id, index)
  local provider = provider_for(provider_id)
  if not provider then return false, "Provedor não encontrado" end
  local keys = normalize(provider)
  index = tonumber(index)
  if not index or index % 1 ~= 0 or index < 1 or index > #keys then
    return false, "Índice de API Key inválido"
  end
  provider.activeKeyIndex = index
  provider.apiKey = keys[index].key
  return store.save()
end

function M.rotate(provider_id, current_index)
  local provider = provider_for(provider_id)
  if not provider then return nil, nil, 0 end
  local keys, active_index = normalize(provider)
  if #keys < 2 then return nil, active_index, #keys end
  local current = tonumber(current_index) or active_index
  local next_index = (current % #keys) + 1
  provider.activeKeyIndex = next_index
  provider.apiKey = keys[next_index].key
  if not store.save() then return nil, nil, #keys end
  return provider.apiKey, next_index, #keys
end

function M.record(provider_id, index, success)
  local provider = provider_for(provider_id)
  if not provider then return false end
  local keys = normalize(provider)
  local item = keys[tonumber(index) or provider.activeKeyIndex]
  if not item then return false end
  local stamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
  local day, changed = stamp:sub(1, 10), false
  if success then
    if item.last_error_at then
      item.last_error_at, item.last_ok = nil, stamp
      changed = true
    elseif not item.last_ok or item.last_ok:sub(1, 10) ~= day then
      item.last_ok, changed = stamp, true
    end
  elseif not item.last_error_at or item.last_error_at:sub(1, 10) ~= day then
    item.last_error_at, changed = stamp, true
  end
  return changed and store.save() or true
end

function M.replace(provider_id, key)
  local provider = provider_for(provider_id)
  if not provider then return false, "Provedor não encontrado" end
  if type(key) ~= "string" or key:match("^%s*$") then return false, "API Key inválida" end
  key = key:match("^%s*(.-)%s*$")
  local safe, invalid_char = require("agent.security").is_safe(key)
  if not safe then
    return false, "API Key contém caractere não permitido: " .. tostring(invalid_char)
  end
  provider.apiKeys = { { key = key } }
  provider.activeKeyIndex, provider.apiKey = 1, key
  return store.save()
end

return M
