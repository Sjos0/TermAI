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

-- Ciclo de topo no boot (Issue #370 item B):
-- com a ativa em N, testa sequencialmente as chaves anteriores (1 .. N-1).
-- A primeira saudável (mais próxima do topo) vira a ativa.
-- Se todas as anteriores falharem, permanece na ativa atual sem re-testá-la.
-- Já no topo (índice 1) ou sem chaves: não dispara probes.
function M.prefer_top_on_boot(ref, options)
  local resolver = require("models.resolve")
  local active, err = resolver.resolve(ref)
  if not active then return false, nil, err end

  local models = require("models")
  local provider_id = active.provider
  local current_index = active.api_key_index or 1
  local keys = models.list_api_keys(provider_id) or {}
  if #keys == 0 or current_index <= 1 then
    return false, current_index
  end

  for index = 1, current_index - 1 do
    local ok = M.test(provider_id, ref, index, options)
    if ok then
      local saved, save_error = models.set_active_api_key(provider_id, index)
      if not saved then return false, current_index, save_error end
      return true, index
    end
  end
  return false, current_index
end

return M
