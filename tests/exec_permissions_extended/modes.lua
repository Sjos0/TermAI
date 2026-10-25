-- Seções 8-11: edge cases do check, denial tracking, get/set mode e integração.
local harness = require("tests.helpers.harness")
local security = require("tools.exec.security")
local perms = require("tools.exec.permissions")
local T, sec = harness.T, harness.sec

local M = {}

function M.run()
  -- ============================================================================
  -- 8. PERMISSIONS.LUA — COMANDOS VAZIOS/NIL NO CHECK
  -- ============================================================================
  sec("8. Edge Cases no Check")

  -- Comando nil
  local check_nil = perms.check("Exec", nil)
  T("Check com comando nil: não crasha", check_nil ~= nil)

  -- Comando vazio
  local check_empty = perms.check("Exec", "")
  T("Check com comando vazio: retorna allowed (sem subcomandos)", 
    check_empty.allowed == true)


  -- ============================================================================
  -- 9. DENIAL TRACKING — MÚLTIPLAS FERRAMENTAS
  -- ============================================================================
  sec("9. Denial Tracking — Múltiplas Ferramentas")

  perms.reset_denials("tool_a")
  perms.reset_denials("tool_b")

  -- Negations independentes por ferramenta
  perms.increment_denial("tool_a")
  perms.increment_denial("tool_a")
  T("tool_a tem 2 negações", perms.get_denial_count("tool_a") == 2)
  T("tool_b tem 0 negações", perms.get_denial_count("tool_b") == 0)

  -- Limpa
  perms.reset_denials("tool_a")
  perms.reset_denials("tool_b")


  -- ============================================================================
  -- 10. PERMISSIONS.LUA — GET_MODE E SET_MODE
  -- ============================================================================
  sec("10. Get/Set Mode")

  local saved_mode = perms.get_mode()

  perms.set_mode("bypass")
  T("set_mode('bypass'): get_mode retorna 'bypass'", perms.get_mode() == "bypass")

  perms.set_mode("acceptEdits")
  T("set_mode('acceptEdits'): get_mode retorna 'acceptedits'", perms.get_mode() == "acceptedits")

  perms.set_mode("default")
  T("set_mode('default'): get_mode retorna 'default'", perms.get_mode() == "default")

  -- Restaura
  perms.set_mode(saved_mode)


  -- ============================================================================
  -- 11. INTEGRAÇÃO — SECURITY + PERMISSIONS
  -- ============================================================================
  sec("11. Integração Security + Permissions")

  perms.set_mode("default")

  -- Comando seguro (safe command) deve passar direto
  local integration_safe = perms.check("Exec", "echo hello")
  T("Integração: echo é auto-aprovado (safe command)", integration_safe.allowed == true)

  -- Comando perigoso sem regra deve pedir permissão
  local integration_danger = perms.check("Exec", "rm -rf /tmp/test")
  T("Integração: rm sem regra pede permissão", 
    integration_danger.allowed == false and integration_danger.reason == "ask")

  -- Comando perigoso com deny rule deve ser bloqueado
  perms.add_rule("rm -rf *", "deny", false)
  local integration_denied = perms.check("Exec", "rm -rf /tmp/test")
  T("Integração: rm com deny rule é bloqueado", 
    integration_denied.allowed == false and integration_denied.reason == "deny")
  perms.remove_rule("rm -rf *", "deny", false)

  -- Restaura
  perms.set_mode(saved_mode)
end

return M
