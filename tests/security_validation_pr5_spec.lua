-- tests/security_validation_pr5_spec.lua
-- PR #5: Sentinel — Fix potential command injection
-- Testa a proteção contra injeção de comandos em endpoints e API keys
package.path = os.getenv("HOME") .. "/TermAI/?.lua;" .. os.getenv("HOME") .. "/TermAI/?/init.lua;" .. package.path

local pass, fail, skip = 0, 0, 0
local function TEST(name, ok, detail)
  if ok == nil then
    skip = skip + 1
    print("  SKIP: " .. name .. (detail and (" — " .. detail) or ""))
  elseif ok then
    pass = pass + 1
  else
    fail = fail + 1
    print("  FAIL: " .. name .. (detail and (" — " .. detail) or ""))
  end
end

print("\n=== PR #5 — Sentinel: Command Injection Protection ===\n")

-- ═══════════════════════════════════════════════════════
-- FASE 1: Isolamento — Testes do módulo validator
-- ═══════════════════════════════════════════════════════
print("--- Fase 1: Isolamento (validator) ---")

-- Verificar se o módulo validator existe (só existe após a PR)
local validator_ok, validator = pcall(require, "agent.security.validator")
if not validator_ok then
  print("  ⚠️  agent.security.validator não existe (baseline — esperado)")
  print("  Todos os testes de is_safe serão pulados")
else
  -- Testes de is_safe com valores seguros
  TEST("is_safe: URL limpa retorna true",
    validator.is_safe("https://api.openrouter.ai/api/v1") == true)

  TEST("is_safe: API key limpa retorna true",
    validator.is_safe("sk-or-v1-abcdef1234567890") == true)

  TEST("is_safe: string vazia retorna true",
    validator.is_safe("") == true)

  TEST("is_safe: nil retorna true",
    validator.is_safe(nil) == true)

  -- Testes de is_safe com valores inseguros
  TEST("is_safe: URL com vírgula-e-vírgula retorna false",
    validator.is_safe("https://api.openrouter.ai; rm -rf") == false)

  TEST("is_safe: URL com dollar retorna false",
    validator.is_safe("https://api.openrouter.ai/$(whoami)") == false)

  TEST("is_safe: URL com backtick retorna false",
    validator.is_safe("https://api.openrouter.ai/`whoami`") == false)

  TEST("is_safe: URL com pipe retorna false",
    validator.is_safe("https://api.openrouter.ai/v1|sh") == false)

  TEST("is_safe: URL com ampersand retorna false",
    validator.is_safe("https://api.openrouter.ai&cmd") == false)

  TEST("is_safe: API key com aspas duplas retorna false",
    validator.is_safe('sk-or-v1" -H "SomeHeader') == false)

  TEST("is_safe: URL com parênteses retorna false",
    validator.is_safe("https://api.openrouter.ai(cmd)") == false)

  TEST("is_safe: URL com chaves retorna false",
    validator.is_safe("https://api.openrouter.ai{cmd}") == false)

  TEST("is_safe: URL com < retorna false",
    validator.is_safe("https://api.openrouter.ai<") == false)

  TEST("is_safe: URL com > retorna false",
    validator.is_safe("https://api.openrouter.ai>") == false)

  TEST("is_safe: URL com barra invertida retorna false",
    validator.is_safe("https://api.openrouter.ai\\") == false)

  TEST("is_safe: string com newline retorna false",
    validator.is_safe("safe\nunsafe") == false)

  -- Verificar se retorna segundo valor (char problemático)
  local safe, char = validator.is_safe("test;injection")
  TEST("is_safe retorna char problemático como 2o retorno",
    safe == false and char == ";")

  -- Testes de validate_chars (deve chamar os.exit — isolar com pcall)
  -- NOTA: validate_chars chama os.exit(1), então precisamos de proteção
  TEST("validate_chars: valor seguro não chama os.exit",
    validator.validate_chars("https://api.openrouter.ai", "test"))

  -- Para testar que validate_chars rejeita, precisamos interceptar os.exit
  -- Usamos pcall + sobrescrita temporária
  local exit_called = false
  local orig_exit = os.exit
  os.exit = function(code) exit_called = code end
  validator.validate_chars("bad;value", "test")
  local caught_exit = exit_called
  os.exit = orig_exit
  TEST("validate_chars: valor inseguro chama os.exit(1)",
    caught_exit == 1)
end

-- ═══════════════════════════════════════════════════════
-- FASE 1b: Isolamento — Testes do módulo security (fachada)
-- ═══════════════════════════════════════════════════════
print("\n--- Fase 1b: Isolamento (security facade) ---")

local security = require("agent.security")

-- Verificar se is_safe existe na fachada (só existe após a PR)
if type(security.is_safe) == "function" then
  TEST("security.is_safe: delega corretamente para validator",
    security.is_safe("https://api.openrouter.ai") == true)

  TEST("security.is_safe: detecta caractere inseguro",
    security.is_safe("https://api.openrouter.ai; rm -rf") == false)
else
  print("  ⚠️  security.is_safe não existe (baseline — esperado)")
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
print("\n--- Fase 5: Adversarial (edge cases) ---")

if validator_ok then
  -- Unicode e caracteres especiais
  TEST("is_safe: URL com unicode seguro retorna true",
    validator.is_safe("https://api.example.com/v1/café") == true)

  TEST("is_safe: string com aspas simples retorna false",
    validator.is_safe("it's unsafe") == false)

  TEST("is_safe: string com \\n retorna false",
    validator.is_safe("line1\nline2") == false)

  TEST("is_safe: string com \\r retorna false",
    validator.is_safe("line1\rline2") == false)

  -- strings vazias e nil
  TEST("is_safe: nil é seguro",
    validator.is_safe(nil) == true)

  TEST("is_safe: string vazia é segura",
    validator.is_safe("") == true)

  -- Endpoint longo e complexo
  TEST("is_safe: URL complexa mas segura retorna true",
    validator.is_safe("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent") == true)
end

-- ═══════════════════════════════════════════════════════
-- RESULTADO
-- ═══════════════════════════════════════════════════════
print(string.format(
  "\n══ RESULTADO: %d passaram, %d falharam, %d pulados (total: %d) ══",
  pass, fail, skip, pass + fail + skip))

if fail > 0 then
  print("⚠️  FALHA DETECTADA — revisar antes de merge")
  os.exit(1)
else
  print("✅ Todos os testes passaram")
end
