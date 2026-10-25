-- tests/security_validation_pr5_spec/02_parte.lua — parte de security_validation_pr5_spec.lua (ver fachada).
local harness = require("tests.helpers.harness")

local M = {}

function M.run()

  local validator_ok, validator = pcall(require, "agent.security.validator")
  local function TEST(name, ok, detail)
    if ok == nil then
      harness.skip = harness.skip + 1
      print("  SKIP: " .. name .. (detail and (" — " .. detail) or ""))
    elseif ok then
      harness.pass = harness.pass + 1
    else
      harness.fail = harness.fail + 1
      print("  FAIL: " .. name .. (detail and (" — " .. detail) or ""))
    end
  end


  -- ═══════════════════════════════════════════════════════
  -- FASE 3: Integração — test_connection com payloads maliciosos
  -- ═══════════════════════════════════════════════════════
  print("\n--- Fase 3: Integração (test_connection) ---")

  local validate = require("models.validate")

  -- Mock mínimo: interceptar io.popen para não fazer requests reais
  local popen_call = nil
  local orig_popen = io.popen
  io.popen = function(cmd)
    popen_call = cmd
    return {
      read = function(self) return '{"choices":[{"message":{"content":"hi"}}]}\n200' end,
      close = function(self) end
    }
  end

  -- Teste 1: endpoint malicioso — deve ser recusado (após PR) ou aceito (baseline)
  popen_call = nil
  local ok1, err1 = validate.test_connection({
    model_id = "test",
    endpoint = "https://api.openrouter.ai; rm -rf /",
    api_key = "safe-key",
    auth_style = "bearer"
  })

  if ok1 == false and err1 and err1:find("segurança") then
    TEST("test_connection recusa endpoint com vírgula-e-vírgula", true)
  elseif ok1 == nil then
    -- Pode ter chamado os.exit
    TEST("test_connection recusa endpoint com vírgula-e-vírgula", false,
      "chamou os.exit ao invés de retornar erro")
  else
    -- Baseline: não recusa (executa o curl — vulnerável)
    TEST("test_connection recusa endpoint com vírgula-e-vírgula", false,
      "VULNERÁVEL: endpoint malicioso foi aceito")
  end

  -- Teste 2: API key com backtick
  popen_call = nil
  local ok2, err2 = validate.test_connection({
    model_id = "test",
    endpoint = "https://api.openrouter.ai/api/v1",
    api_key = "invalid`key`",
    auth_style = "bearer"
  })

  if ok2 == false and err2 and err2:find("segurança") then
    TEST("test_connection recusa API key com backtick", true)
  else
    TEST("test_connection recusa API key com backtick", false,
      "VULNERÁVEL: API key maliciosa foi aceita")
  end

  -- Teste 3: API key com dollar (subshell)
  popen_call = nil
  local ok3, err3 = validate.test_connection({
    model_id = "test",
    endpoint = "https://api.openrouter.ai/api/v1",
    api_key = "$(whoami)",
    auth_style = "bearer"
  })

  if ok3 == false and err3 and err3:find("segurança") then
    TEST("test_connection recusa API key com subshell $()", true)
  else
    TEST("test_connection recusa API key com subshell $()", false,
      "VULNERÁVEL: subshell injection foi aceita")
  end

  -- Teste 4: Endpoint seguro + key segura (happy path)
  popen_call = nil
  local ok4, err4 = validate.test_connection({
    model_id = "test",
    endpoint = "https://api.openrouter.ai/api/v1",
    api_key = "sk-or-v1-safe123",
    auth_style = "bearer"
  })

  TEST("test_connection aceita endpoint/key seguros",
    ok4 == true and popen_call ~= nil)

  -- Restaurar io.popen original
  io.popen = orig_popen

  -- ═══════════════════════════════════════════════════════
  -- FASE 5: Adversarial — Edge cases
  -- ═══════════════════════════════════════════════════════
end

return M
