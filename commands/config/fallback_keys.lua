-- Lógica compartilhada de teste/saúde de API Keys para TUI, CLI e boot.
local models = require("models")
local health = require("commands.config.fallback_health")
local M = {}

function M.mask(key)
  key = tostring(key or "")
  if #key <= 4 then return string.rep("*", math.max(4, #key)) end
  return string.rep("*", math.min(8, #key - 4)) .. key:sub(-4)
end

function M.model_ref(provider_id)
  local active = models.get_active()
  if type(active) == "string" and active:match("^" .. provider_id:gsub("([^%w])", "%%%1") .. "/") then
    return active
  end
  local items = models.list(provider_id)
  return items[1] and items[1].ref or nil
end

function M.test_key(provider_id, index, ref)
  ref = ref or M.model_ref(provider_id)
  if not ref then return false, "Nenhum modelo cadastrado para o provedor" end
  local ok, message = models.test_api_key(provider_id, ref, index)
  return ok == true, health.error_message(message, (function()
    local keys = models.list_api_keys(provider_id) or {}
    return keys[index] and keys[index].key
  end)())
end

function M.test_all(provider_id)
  local keys = models.list_api_keys(provider_id) or {}
  local ref = M.model_ref(provider_id)
  if #keys == 0 or not ref then return nil, "Adicione uma chave e um modelo antes de testar" end
  local results, invalid = {}, {}
  for index, item in ipairs(keys) do
    local ok, message = M.test_key(provider_id, index, ref)
    results[#results + 1] = {
      index = index, masked = M.mask(item.key), ok = ok, message = message,
    }
    if not ok then invalid[#invalid + 1] = index end
  end
  return results, invalid
end

function M.dashboard(provider_id)
  local keys = models.list_api_keys(provider_id) or {}
  local rows = {}
  for index, item in ipairs(keys) do
    local state
    if item.last_error_at and (not item.last_ok or item.last_error_at > item.last_ok) then
      state = "FALHA"
    elseif item.last_ok then
      state = "OK"
    else
      state = "SEM TESTE"
    end
    rows[#rows + 1] = {
      index = index, masked = M.mask(item.key), state = state,
      active = item.active == true,
      last = health.label(item):gsub("^%s+", ""),
    }
  end
  return rows
end

return M
