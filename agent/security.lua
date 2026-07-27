local M = {}
local validator = require("agent.security.validator")

function M.is_safe(val)
  return validator.is_safe(val)
end

function M.validate(endpoint, api_key)
  -- Endpoint é obrigatório
  if not endpoint or endpoint == "" then
    print("[ERRO] endpoint está vazio")
    os.exit(1)
  end
  validator.validate_chars(endpoint, "endpoint")

  -- API Key é OPCIONAL (provedores sem autenticação deixam vazio)
  if api_key and api_key ~= "" then
    validator.validate_chars(api_key, "api_key")
  end
end

return M
