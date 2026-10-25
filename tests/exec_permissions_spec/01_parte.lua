-- tests/exec_permissions_spec/01_parte.lua — parte de exec_permissions_spec.lua (ver fachada).
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
  -- 1. TESTES DE ANÁLISE DE SEGURANÇA (security.lua)
  -- ============================================================================
  sec("1. Análise de Segurança (security.lua)")

  -- Teste de comando seguro
  local clean_res = security.analyze("echo 'Hello World'")
  T("Comando limpo: echo", clean_res.safe == true and clean_res.severity == "low")

  -- Teste de comandos vazios
  local empty_res = security.analyze("")
  T("Comando vazio é seguro", empty_res.safe == true and empty_res.severity == "low")

  -- Teste de Path Traversal
  local traversal_res = security.analyze("cat ../../etc/passwd")
  T("Detecta path traversal '../'", traversal_res.safe == false and traversal_res.severity == "high")

  local passwd_res = security.analyze("cat /etc/passwd")
  T("Detecta acesso a arquivo sensível (/etc/passwd)", passwd_res.safe == false and passwd_res.severity == "high")

  -- Teste de Comandos Destrutivos
  local rm_res = security.analyze("rm -rf /data")
  T("Detecta 'rm -rf'", rm_res.safe == false and rm_res.severity == "high")

  local reboot_res = security.analyze("reboot")
  T("Detecta 'reboot'", reboot_res.safe == false and reboot_res.severity == "high")

  -- Teste de Execução Aninhada
  local nested_sub_res = security.analyze("echo $(whoami)")
  T("Detecta subshell $()", nested_sub_res.severity == "medium")

  local backticks_res = security.analyze("echo `whoami`")
  T("Detecta backticks", backticks_res.severity == "medium")

  -- Teste de Injeção de Comandos
  local semi_res = security.analyze("ls; rm -f file")
  T("Detecta ponto e vírgula ';'", semi_res.severity == "medium")

  local pipe_res = security.analyze("cat file | grep text")
  T("Detecta pipe '|'", pipe_res.severity == "medium")

  local or_res = security.analyze("ls || echo 'falhou'")
  T("Detecta ou-lógico '||'", or_res.severity == "medium")

  local and_res = security.analyze("mkdir dir && cd dir")
  T("Detecta e-lógico '&&'", and_res.severity == "medium")


  -- ============================================================================
  -- 2. TESTES DE NÍVEIS DE SEGURANÇA (safetyLevel)
  -- ============================================================================
  sec("2. Níveis de Segurança (safetyLevel)")

  -- Mock os.getenv para simular as variáveis de ambiente com segurança
  local orig_getenv = os.getenv
  local mock_env = {}
  os.getenv = function(name)
    if mock_env[name] ~= nil then
      return mock_env[name]
    end
    return orig_getenv(name)
  end

  -- Simula safetyLevel alterando variável de ambiente
  mock_env["OPENCLAUDE_SAFETY_LEVEL"] = "strict"
  local strict_res = security.analyze("echo hello && ls")
  T("Strict: aviso médio torna o comando inseguro (safe = false)", strict_res.safe == false and strict_res.severity == "medium")

  mock_env["OPENCLAUDE_SAFETY_LEVEL"] = "balanced"
  local balanced_res = security.analyze("echo hello && ls")
  T("Balanced: aviso médio mantém comando executável (safe = true)", balanced_res.safe == true and balanced_res.severity == "medium")

  mock_env["OPENCLAUDE_SAFETY_LEVEL"] = "permissive"
  local permissive_res = security.analyze("echo hello && ls")
  T("Permissive: ignora avisos médios de injeção simples", #permissive_res.warnings == 0)

  -- Restaura o getenv original
  os.getenv = orig_getenv


  -- ============================================================================
  -- 3. TESTES DE REGRAS E MATCHING DE CURINGAS (permissions.lua)
  -- ============================================================================
  sec("3. Regras e Curingas (permissions.lua)")

  -- Teste de conversão de curinga com espaço opcional
  T("Conversão de 'sort *' para padrão opcional", perms.wildcard_to_pattern("sort *") == "^sort$")
  T("Conversão de 'git commit *' para padrão opcional", perms.wildcard_to_pattern("git commit *") == "^git commit$")
  T("Conversão de '*' normal", perms.wildcard_to_pattern("*") == "^.*$")

  -- Teste de correspondência de regras
  T("Matches_rule: 'sort' bate com 'sort *'", perms.matches_rule("sort", "sort *") == true)
  T("Matches_rule: 'sort -rn' bate com 'sort *'", perms.matches_rule("sort -rn", "sort *") == true)
  T("Matches_rule: 'sorteo' NÃO bate com 'sort *'", perms.matches_rule("sorteo", "sort *") == false)
  T("Matches_rule: 'npm run start' bate com 'npm run *'", perms.matches_rule("npm run start", "npm run *") == true)
  T("Matches_rule: case-insensitive check", perms.matches_rule("SORT -rn", "sort *") == true)


end

return M
