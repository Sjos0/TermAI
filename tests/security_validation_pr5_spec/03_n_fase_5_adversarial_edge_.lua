-- tests/security_validation_pr5_spec/03_n_fase_5_adversarial_edge_.lua — parte de security_validation_pr5_spec.lua (ver fachada).
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
end

return M
