local store = require("models.store")
local M = {}

function M.get_active()
  return store.data().active
end

function M.set_active(ref)
  store.data().active = ref
  return store.save()
end

function M.add_model(provider_id, model_data)
  local d = store.data()
  local provider = d.providers[provider_id]
  if not provider then return false, "Provedor não encontrado: " .. provider_id end
  for _, m in ipairs(provider.models or {}) do
    if m.id == model_data.id then
      return false, "Modelo já existe: " .. model_data.id
    end
  end
  provider.models = provider.models or {}
  provider.models[#provider.models + 1] = model_data
  return store.save()
end

function M.remove_model(provider_id, model_id)
  local d = store.data()
  local provider = d.providers[provider_id]
  if not provider then return false, "Provedor não encontrado" end
  for i, m in ipairs(provider.models or {}) do
    if m.id == model_id then
      table.remove(provider.models, i)
      if d.active == provider_id .. "/" .. model_id then
        d.active = ""
      end
      return store.save()
    end
  end
  return false, "Modelo não encontrado"
end

function M.add_provider(data)
  local d = store.data()
  if not data.id then return false, "ID do provedor obrigatório" end
  d.providers[data.id] = {
    baseUrl = data.baseUrl,
    apiKey  = data.apiKey,
    api     = data.api,
    models  = data.models or {},
  }
  return store.save()
end

function M.remove_provider(provider_id)
  local d = store.data()
  if not d.providers[provider_id] then
    return false, "Provedor não encontrado"
  end
  if d.active:match("^" .. provider_id .. "/") then
    d.active = ""
  end
  d.providers[provider_id] = nil
  return store.save()
end

function M.update_api_key(provider_id, key)
  local d = store.data()
  local provider = d.providers[provider_id]
  if not provider then return false, "Provedor não encontrado" end
  provider.apiKey = key
  return store.save()
end

return M
