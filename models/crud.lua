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

-- Atualiza campos de um modelo já cadastrado, in-place. `updates` é uma
-- tabela parcial (só os campos que mudaram). Se updates.id vier preenchido,
-- também sincroniza d.active — evita referência pendurada apontando pro
-- id antigo se o modelo renomeado for o ativo no momento.
function M.update_model(provider_id, model_id, updates)
  local d = store.data()
  local provider = d.providers[provider_id]
  if not provider then return false, "Provedor não encontrado: " .. provider_id end

  local model = nil
  for _, m in ipairs(provider.models or {}) do
    if m.id == model_id then model = m; break end
  end
  if not model then return false, "Modelo não encontrado: " .. model_id end

  if updates.id and updates.id ~= model_id then
    for _, m in ipairs(provider.models or {}) do
      if m.id == updates.id then
        return false, "Já existe um modelo com esse ID: " .. updates.id
      end
    end
    local old_ref = provider_id .. "/" .. model_id
    if d.active == old_ref then
      d.active = provider_id .. "/" .. updates.id
    end
  end

  for k, v in pairs(updates) do
    model[k] = v
  end
  return store.save()
end

return M
