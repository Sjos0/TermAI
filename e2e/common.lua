package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- e2e/common.lua — Preparação comum dos testes reais: registra o provedor Kilo (sem chave) no store de modelos.
local M = {}

-- Equivale a "TermAI models add-provider" para o Kilo, que não exige chave.
function M.ensure_kilo()
  local kilo   = require("providers.kilo")
  local store  = require("models.store")
  local crud   = require("models.crud")
  store.load()
  local ok, err = crud.add_provider({
    id = kilo.id, baseUrl = kilo.baseUrl, apiKey = "", api = kilo.api, models = kilo.models,
  })
  if not ok then error("não foi possível registrar o provedor Kilo: " .. tostring(err)) end
  return true
end

return M
