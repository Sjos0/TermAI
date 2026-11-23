local validate = require("models.validate")
local M = {}

local DEFAULT_TEST_OPTIONS = {
  connect_timeout = 2,
  max_time = 6,
  speed_time = 2,
  speed_limit = 1,
}

-- Limites de startup: evita boot silencioso longo em Termux (review PR #371).
local DEFAULT_BOOT_MAX_PREVIOUS = 3
local DEFAULT_BOOT_WALL_SECONDS = 9

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

local function notify_progress(on_progress, event, payload)
  if type(on_progress) ~= "function" then return end
  pcall(on_progress, event, payload)
end

-- Ciclo de topo no boot (Issue #370 item B + review PR #371):
-- com a ativa em N, testa sequencialmente as anteriores a partir do topo.
-- A primeira saudável vira a ativa. Se todas falharem (ou orçamento esgotar),
-- permanece na ativa atual sem re-testá-la.
-- Já no topo / sem chaves: zero probes.
-- Orçamento: no máximo `max_previous` índices (default 3) e `max_wall_seconds`
-- (default 9s), com callback de progresso por probe.
function M.prefer_top_on_boot(ref, options)
  options = options or {}
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

  local max_previous = tonumber(options.max_previous) or DEFAULT_BOOT_MAX_PREVIOUS
  if max_previous < 1 then max_previous = 1 end
  local wall = tonumber(options.max_wall_seconds) or DEFAULT_BOOT_WALL_SECONDS
  if wall < 1 then wall = 1 end
  local last_probe = math.min(current_index - 1, max_previous)
  local on_progress = options.on_progress
  local started = os.time()

  notify_progress(on_progress, "start", {
    from = 1, to = last_probe, current = current_index,
  })

  for index = 1, last_probe do
    if os.time() - started >= wall then
      notify_progress(on_progress, "budget", {
        index = index, elapsed = os.time() - started, wall = wall,
      })
      break
    end
    notify_progress(on_progress, "probe", {
      index = index, total = last_probe,
    })
    local ok = M.test(provider_id, ref, index, options)
    if ok then
      local saved, save_error = models.set_active_api_key(provider_id, index)
      if not saved then return false, current_index, save_error end
      notify_progress(on_progress, "recovered", {
        index = index, previous = current_index,
      })
      return true, index
    end
  end

  notify_progress(on_progress, "keep", { index = current_index })
  return false, current_index
end

return M
