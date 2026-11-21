local store = require("models.store")
local M = {}

local function provider_for(provider_id)
  return store.data().providers[provider_id]
end

local function normalize(provider)
  store.normalize_provider(provider)
  return provider.apiKeys, provider.activeKeyIndex
end

function M.preview(provider_id, current_index)
  local provider = provider_for(provider_id)
  if not provider then return nil, nil, 0 end
  local keys, active_index = normalize(provider)
  if #keys < 2 then return nil, active_index, #keys end
  local current = tonumber(current_index) or active_index
  if current % 1 ~= 0 or current < 1 or current > #keys then
    return nil, active_index, #keys
  end
  local next_index = (current % #keys) + 1
  return keys[next_index].key, next_index, #keys, active_index
end

function M.commit(provider_id, next_index, previous_index)
  local provider = provider_for(provider_id)
  if not provider then return false, "Provedor não encontrado" end
  local keys, active_index = normalize(provider)
  next_index, previous_index = tonumber(next_index), tonumber(previous_index)
  if not next_index or next_index % 1 ~= 0 or not keys[next_index] then
    return false, "Índice de rotação inválido"
  end
  if not previous_index or active_index ~= previous_index then
    return false, "Chave ativa mudou durante a rotação"
  end
  provider.activeKeyIndex = next_index
  provider.apiKey = keys[next_index].key
  if store.save() then return true end
  provider.activeKeyIndex = previous_index
  provider.apiKey = keys[previous_index] and keys[previous_index].key or ""
  return false, "Não foi possível persistir a rotação da API Key"
end

return M
