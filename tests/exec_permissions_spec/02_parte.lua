-- tests/exec_permissions_spec/02_parte.lua — parte de exec_permissions_spec.lua (ver fachada).
local harness = require("tests.helpers.harness")

local M = {}

function M.run()

  -- Config isolado: regras salvas pelo usuário em ~/.TermAI/config.json não podem
  -- alterar o resultado destes testes (issue #129). Deve vir antes de qualquer require.
  require("tests.helpers.config_fake").install()

  local security = require("tools.exec.security")
  local perms = require("tools.exec.permissions")

  local function T(name, ok, detail)
    if ok then
      harness.pass = harness.pass + 1
      print("  ✅ " .. name)
    else
      harness.fail = harness.fail + 1
      print("  ❌ " .. name .. (detail and (" — " .. detail) or ""))
    end
  end

  local function sec(title)
    print("\n=== " .. title .. " ===")
  end


  -- ============================================================================
  -- 4. TESTES DE VERIFICAÇÃO DE PERMISSÕES (check)
  -- ============================================================================
  sec("4. Verificação de Permissões (check)")

  -- Salva modo original
  local orig_mode = perms.get_mode()

  -- Modo bypass
  perms.set_mode("bypass")
  local check_bypass = perms.check("Exec", "rm -rf /")
  T("Bypass: permite qualquer comando mesmo perigoso", check_bypass.allowed == true)

  -- Modo acceptEdits
  perms.set_mode("acceptEdits")
  local check_ed_write = perms.check("Write", "conteudo")
  T("acceptEdits: auto-permite escrita", check_ed_write.allowed == true)

  local check_ed_exec = perms.check("Exec", "sort")
  T("acceptEdits: ainda bloqueia/pergunta para exec (bash)", check_ed_exec.allowed == false and check_ed_exec.reason == "ask")

  -- Modo default
  perms.set_mode("default")

  -- Safe commands
  local check_safe = perms.check("Exec", "echo 'olá'")
  T("Default: auto-permite comandos seguros (echo)", check_safe.allowed == true)

  -- Comandos não mapeados pedem permissão
  local check_ask = perms.check("Exec", "sort -r")
  T("Default: pede permissão para comando desconhecido", check_ask.allowed == false and check_ask.reason == "ask")

  -- Adicionando regra temporária na sessão
  perms.add_rule("sort *", "allow", false) -- em memória
  local check_rule_ok = perms.check("Exec", "sort -r")
  T("Default: permite comando que bate com regra de sessão adicionada", check_rule_ok.allowed == true)

  -- Removendo regra temporária
  perms.remove_rule("sort *", "allow", false)
  local check_rule_removed = perms.check("Exec", "sort -r")
  T("Default: volta a pedir permissão após remover a regra", check_rule_removed.allowed == false and check_rule_removed.reason == "ask")

  -- Adicionando regra permanente (persistida)
  perms.add_rule("npm run *", "allow", true) -- persistida no config.json
  local check_persist_ok = perms.check("Exec", "npm run build")
  T("Default: permite comando que bate com regra persistente", check_persist_ok.allowed == true)

  -- Comandos proibidos por regra deny
  perms.add_rule("rm -rf *", "deny", true)
  local check_deny = perms.check("Exec", "rm -rf /tmp/teste")
  T("Default: bloqueia explicitamente se bater com regra deny", check_deny.allowed == false and check_deny.reason == "deny")

  -- Limpa regras criadas no config para não poluir
  perms.remove_rule("npm run *", "allow", true)
  perms.remove_rule("rm -rf *", "deny", true)

  -- Restaura modo original
  perms.set_mode(orig_mode)


  -- ============================================================================
  -- 5. TESTES DE DENIAL TRACKING
  -- ============================================================================
  sec("5. Denial Tracking")

  perms.reset_denials("exec")
  T("Contagem inicial de negações é 0", perms.get_denial_count("exec") == 0)

  perms.increment_denial("exec")
  perms.increment_denial("exec")
  T("Contagem após 2 negações é 2", perms.get_denial_count("exec") == 2)

  local reached = perms.increment_denial("exec")
  T("Retorna true quando atinge o limite de 3 negações", reached == true)
  T("Contagem é resetada após atingir o limite", perms.get_denial_count("exec") == 0)


  -- ============================================================================
  -- RELATÓRIO FINAL
  -- ============================================================================
end

return M
