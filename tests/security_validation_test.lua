-- tests/security_validation_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local security = require("agent.security")
local validate = require("models.validate")

local pass, fail = 0, 0
local function T(n, ok, d)
  if ok then
    pass = pass + 1
  else
    fail = fail + 1
    print("  FAIL: " .. n .. (d and (" — " .. d) or ""))
  end
end

print("\n=== Testes de Segurança: Validação de Endpoints e Chaves ===")

-- 1. Testes de segurança pura (is_safe)
T("Safe URL", security.is_safe("https://api.openrouter.ai/api/v1") == true)
T("Unsafe URL with semicolon", security.is_safe("https://api.openrouter.ai; rm -rf") == false)
T("Unsafe URL with dollar", security.is_safe("https://api.openrouter.ai/$(whoami)") == false)
T("Unsafe URL with backtick", security.is_safe("https://api.openrouter.ai/`whoami`") == false)
T("Unsafe URL with pipe", security.is_safe("https://api.openrouter.ai/v1|sh") == false)
T("Unsafe key with double quote", security.is_safe('sk-or-v1" -H "SomeHeader') == false)
T("Safe key", security.is_safe('sk-or-v1-abcdef1234567890') == true)

-- 2. Testes de conexão simulada (test_connection com payload malicioso)
local bad_active = {
  model_id = "test-model",
  endpoint = "https://api.openrouter.ai; rm -rf /",
  api_key = "safe-key",
  auth_style = "bearer"
}
local ok, err = validate.test_connection(bad_active)
T("test_connection recusa endpoint malicioso", ok == false and err:find("Erro de segurança") ~= nil)

local bad_active_key = {
  model_id = "test-model",
  endpoint = "https://api.openrouter.ai/api/v1",
  api_key = "invalid`key",
  auth_style = "bearer"
}
local ok2, err2 = validate.test_connection(bad_active_key)
T("test_connection recusa api_key maliciosa", ok2 == false and err2:find("Erro de segurança") ~= nil)

print(string.format("\nRESULTADO: %d passaram, %d falharam (total: %d)", pass, fail, pass + fail))
if fail > 0 then os.exit(1) end
