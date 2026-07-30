-- tests/exec_permissions_extended.lua — Testes estendidos para cobrir gaps do spec
-- Complementa exec_permissions_spec.lua com cenários de borda e integração
package.path = "./?.lua;./?/init.lua;" .. package.path

local security = require("tools.exec.security")
local perms = require("tools.exec.permissions")

local pass, fail = 0, 0
local function T(name, ok, detail)
  if ok then
    pass = pass + 1
    print("  ✅ " .. name)
  else
    fail = fail + 1
    print("  ❌ " .. name .. (detail and (" — " .. detail) or ""))
  end
end

local function sec(title)
  print("\n=== " .. title .. " ===")
end

-- ============================================================================
-- 1. SECURITY.LUA — COMANDOS DESTRUTIVOS ADICIONAIS
-- ============================================================================
sec("1. Comandos Destrutivos Adicionais")

local rmdir_res = security.analyze("rmdir /tmp/test")
T("Detecta 'rmdir'", rmdir_res.safe == false and rmdir_res.severity == "high")

local mkfs_res = security.analyze("mkfs.ext4 /dev/sda1")
T("Detecta 'mkfs'", mkfs_res.safe == false and mkfs_res.severity == "high")

local dd_res = security.analyze("dd if=/dev/zero of=/dev/sda")
T("Detecta 'dd'", dd_res.safe == false and dd_res.severity == "high")

local shutdown_res = security.analyze("shutdown -h now")
T("Detecta 'shutdown'", shutdown_res.safe == false and shutdown_res.severity == "high")

local shred_res = security.analyze("shred -vfz /tmp/secret.txt")
T("Detecta 'shred'", shred_res.safe == false and shred_res.severity == "high")


-- ============================================================================
-- 2. SECURITY.LUA — PATHS SENSÍVEIS ADICIONAIS
-- ============================================================================
sec("2. Paths Sensíveis Adicionais")

local shadow_res = security.analyze("cat /etc/shadow")
T("Detecta '/etc/shadow'", shadow_res.safe == false and shadow_res.severity == "high")

local sudoers_res = security.analyze("cat /etc/sudoers")
T("Detecta '/etc/sudoers'", sudoers_res.safe == false and sudoers_res.severity == "high")

local proc_res = security.analyze("cat /proc/sys/kernel/hostname")
T("Detecta '/proc/sys'", proc_res.safe == false and proc_res.severity == "high")


-- ============================================================================
-- 3. SECURITY.LUA — EDGE CASES
-- ============================================================================
sec("3. Edge Cases de Segurança")

local nil_res = security.analyze(nil)
T("Comando nil é seguro", nil_res.safe == true and nil_res.severity == "low")

local whitespace_res = security.analyze("   ")
T("Comando só whitespace é seguro", whitespace_res.safe == true and whitespace_res.severity == "low")

-- Múltiplos warnings no mesmo comando
local multi_res = security.analyze("rm -rf /tmp; cat /etc/passwd")
T("Múltiplos warnings detectados (destructive + traversal)", 
  multi_res.safe == false and multi_res.severity == "high" and #multi_res.warnings >= 2)

-- Campo safety_level no retorno
local level_res = security.analyze("ls")
T("Retorno contém campo safety_level", level_res.safety_level ~= nil)


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

local check_priority = perms.check("exec", "test_cmd something")
T("Deny tem prioridade sobre allow", 
  check_priority.allowed == false and check_priority.reason == "deny")

-- Limpa
perms.remove_rule("test_cmd *", "allow", false)
perms.remove_rule("test_cmd *", "deny", false)


-- ============================================================================
-- 8. PERMISSIONS.LUA — COMANDOS VAZIOS/NIL NO CHECK
-- ============================================================================
sec("8. Edge Cases no Check")

-- Comando nil
local check_nil = perms.check("exec", nil)
T("Check com comando nil: não crasha", check_nil ~= nil)

-- Comando vazio
local check_empty = perms.check("exec", "")
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
local integration_safe = perms.check("exec", "echo hello")
T("Integração: echo é auto-aprovado (safe command)", integration_safe.allowed == true)

-- Comando perigoso sem regra deve pedir permissão
local integration_danger = perms.check("exec", "rm -rf /tmp/test")
T("Integração: rm sem regra pede permissão", 
  integration_danger.allowed == false and integration_danger.reason == "ask")

-- Comando perigoso com deny rule deve ser bloqueado
perms.add_rule("rm -rf *", "deny", false)
local integration_denied = perms.check("exec", "rm -rf /tmp/test")
T("Integração: rm com deny rule é bloqueado", 
  integration_denied.allowed == false and integration_denied.reason == "deny")
perms.remove_rule("rm -rf *", "deny", false)

-- Restaura
perms.set_mode(saved_mode)


-- ============================================================================
-- RELATÓRIO FINAL
-- ============================================================================
print("\n" .. string.rep("═", 60))
print(string.format("TESTES ESTENDIDOS: %d passaram, %d falharam", pass, fail))
print(string.rep("═", 60))

if fail > 0 then
  os.exit(1)
end
