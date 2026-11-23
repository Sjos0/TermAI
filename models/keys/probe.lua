local validate = require("models.validate")
local M = {}

local DEFAULT_TEST_OPTIONS = {
  connect_timeout = 2,
  max_time = 6,
  speed_time = 2,
  speed_limit = 1,
}

local function options_for_test(options)
  local result = {}
  for key, value in pairs(DEFAULT_TEST_OPTIONS) do result[key] = value end
  for key, value in pairs(options or {}) do result[key] = value end
  return result
end

-- Testa uma chave sem alterar a chave ativa; registra saúde somente no índice testado.
function M.test(provider_id, ref, index, options)
  local resolver = require("models.resolve")
  local active, err = resolver.resolve(ref, index)
  if not active then return false, err or "Modelo não resolvido" end

  local called, success, message = pcall(
    validate.test_connection, active, options_for_test(options))
  if not called then
    success, message = false, success
  end
  success = success == true
  require("models.keys").record(provider_id, index, success)
  return success, message, active
end

-- Revalida a chave preferida e, se falhar, percorre as demais na ordem configurada.
function M.prefer_top_on_boot(ref, options)
  local resolver = require("models.resolve")
  local active, err = resolver.resolve(ref)
  if not active then return false, nil, err end

  local models = require("models")
  local provider_id = active.provider
  local current_index = active.api_key_index or 1
  local keys = models.list_api_keys(provider_id) or {}
  if #keys == 0 then return false, current_index end

  -- Revalida primeiro a chave preferida já salva.
  local preferred_ok = M.test(provider_id, ref, current_index, options)
  if preferred_ok then return false, current_index end

  -- Se ela falhar, procura a primeira saudável pela ordem configurada.
  for index = 1, #keys do
    if index ~= current_index then
      local ok = M.test(provider_id, ref, index, options)
      if ok then
        local saved, save_error = models.set_active_api_key(provider_id, index)
        if not saved then return false, current_index, save_error end
        return true, index
      end
    end
  end
  return false, current_index
end

return M
