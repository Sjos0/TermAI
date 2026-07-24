local store = require("models.store")
local M = {}

function M.list(provider_id)
  local d = store.data()
  local result = {}
  for pid, prov in pairs(d.providers) do
    if not provider_id or pid == provider_id then
      for _, model in ipairs(prov.models or {}) do
        result[#result + 1] = {
          ref            = pid .. "/" .. model.id,
          provider       = pid,
          id             = model.id,
          name           = model.name or model.id,
          context_window = model.contextWindow or 200000,
          max_tokens     = model.maxTokens or 4096,
          reasoning      = model.reasoning or false,
          input          = model.input or {"text"},
        }
      end
    end
  end
  return result
end

function M.list_providers()
  local d = store.data()
  local result = {}
  for pid, prov in pairs(d.providers) do
    result[#result + 1] = {
      id          = pid,
      base_url    = prov.baseUrl,
      model_count = #(prov.models or {}),
    }
  end
  return result
end

return M
