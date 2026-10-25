-- Seções 4-7: matching avançado, status de sessão, check com config e prioridade deny.
local harness = require("tests.helpers.harness")
local security = require("tools.exec.security")
local perms = require("tools.exec.permissions")
local portable_tmp = require("tests.helpers.tmp")
local T, sec = harness.T, harness.sec

local M = {}

function M.run()
  -- ============================================================================
  -- 4. PERMISSIONS.LUA — MATCHING AVANÇADO
  -- ============================================================================
  sec("4. Matching Avançado de Regras")

  -- Prefixo de dois pontos (ex: rm:*)
  T("matches_rule: 'rm -rf /tmp' bate com 'rm:*'", 
    perms.matches_rule("rm -rf /tmp", "rm:*") == true)
  T("matches_rule: 'rm' bate com 'rm:*'", 
    perms.matches_rule("rm", "rm:*") == true)
  T("matches_rule: 'rmdir' NÃO bate com 'rm:*'", 
    perms.matches_rule("rmdir", "rm:*") == false)

  -- Padrão vazio
  T("matches_rule: padrão vazio retorna false", 
    perms.matches_rule("ls", "") == false)

  -- Case insensitive para deny
  T("matches_rule: 'RM -RF' bate com 'rm -rf *' (case-insensitive)", 
    perms.matches_rule("RM -RF /tmp", "rm -rf *") == true)


  -- ============================================================================
  -- 5. PERMISSIONS.LUA — SESSION STATUS
  -- ============================================================================
  sec("5. Session Status (Ferramentas)")

  -- get_session_status para ferramenta não configurada
  T("get_session_status: ferramenta não configurada retorna nil", 
    perms.get_session_status("ferramenta_inexistente") == nil)

  -- set_session_status e get_session_status
  perms.set_session_status("minha_tool", "always")
  T("set_session_status: salva 'always'", 
    perms.get_session_status("minha_tool") == "always")

  perms.set_session_status("minha_tool", "blocked")
  T("set_session_status: atualiza para 'blocked'", 
    perms.get_session_status("minha_tool") == "blocked")

  -- Limpa
  perms.set_session_status("minha_tool", nil)


  -- ============================================================================
  -- 6. PERMISSIONS.LUA — CHECK COM STATUS DE SESSÃO/CONFIG
  -- ============================================================================
  sec("6. Check com Status de Sessão e Config")

  -- Salva e restaura estado
  local orig_mode = perms.get_mode()
  perms.set_mode("default")

  -- Ferramenta bloqueada na sessão
  perms.set_session_status("blocked_tool", "blocked")
  local check_sess_blocked = perms.check("blocked_tool", "anything")
  T("Ferramenta bloqueada na sessão: allowed = false", 
    check_sess_blocked.allowed == false and check_sess_blocked.reason == "blocked")

  -- Ferramenta sempre permitida na sessão
  perms.set_session_status("always_tool", "always")
  local check_sess_always = perms.check("always_tool", "anything")
  T("Ferramenta always na sessão: allowed = true", 
    check_sess_always.allowed == true)

  -- Limpa sessão
  perms.set_session_status("blocked_tool", nil)
  perms.set_session_status("always_tool", nil)

  -- Ferramenta não-exec SEM status no config pede permissão
  local check_non_exec = perms.check("FerramentaRandomica", "algo")
  T("Ferramenta sem status no config: pede permissão (reason = ask)", 
    check_non_exec.allowed == false and check_non_exec.reason == "ask")

  -- Ferramenta não-exec COM status 'always' no config é auto-aprovada
  require("config.store").PATH = portable_tmp.name("termai_perm_spec") .. ".json"
  require("config.store")._data = nil
  require("config").set("hooks.permissions.Read", "always")
  local check_read = perms.check("Read", "/some/file")
  T("Ferramenta Read (always no config): auto-aprovada", 
    check_read.allowed == true)


  -- ============================================================================
  -- 7. PERMISSIONS.LUA — PRIORIDADE DENY > ALLOW
  -- ============================================================================
  sec("7. Prioridade Deny > Allow")

  -- Adiciona regra allow e deny para o mesmo padrão
  perms.add_rule("test_cmd *", "allow", false)
  perms.add_rule("test_cmd *", "deny", false)

  local check_priority = perms.check("Exec", "test_cmd something")
  T("Deny tem prioridade sobre allow", 
    check_priority.allowed == false and check_priority.reason == "deny")

  -- Limpa
  perms.remove_rule("test_cmd *", "allow", false)
  perms.remove_rule("test_cmd *", "deny", false)
end

return M
