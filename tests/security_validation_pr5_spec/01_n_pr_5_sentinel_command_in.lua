-- tests/security_validation_pr5_spec/01_n_pr_5_sentinel_command_in.lua — parte de security_validation_pr5_spec.lua (ver fachada).
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


  print("\n=== PR #5 — Sentinel: Command Injection Protection ===\n")

  -- ═══════════════════════════════════════════════════════
  -- FASE 1: Isolamento — Testes do módulo validator
  -- ═══════════════════════════════════════════════════════
  print("--- Fase 1: Isolamento (validator) ---")

  -- Verificar se o módulo validator existe (só existe após a PR)
  if not validator_ok then
    print("  ⚠️  agent.security.validator não existe (baseline — esperado)")
    print("  Todos os testes de is_safe serão pulados")
  end

  -- ────────────────────────────────────────────────────────────
  if validator_ok then
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

end

return M
