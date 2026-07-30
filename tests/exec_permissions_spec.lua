-- tests/exec_permissions_spec.lua — Testes unitários para o sistema de permissões e segurança bash
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


-- ============================================================================
-- 4. TESTES DE VERIFICAÇÃO DE PERMISSÕES (check)
-- ============================================================================
sec("4. Verificação de Permissões (check)")

-- Salva modo original
local orig_mode = perms.get_mode()

-- Modo bypass
perms.set_mode("bypass")
local check_bypass = perms.check("exec", "rm -rf /")
T("Bypass: permite qualquer comando mesmo perigoso", check_bypass.allowed == true)

-- Modo acceptEdits
perms.set_mode("acceptEdits")
local check_ed_write = perms.check("Write", "conteudo")
T("acceptEdits: auto-permite escrita", check_ed_write.allowed == true)

local check_ed_exec = perms.check("exec", "sort")
T("acceptEdits: ainda bloqueia/pergunta para exec (bash)", check_ed_exec.allowed == false and check_ed_exec.reason == "ask")

-- Modo default
perms.set_mode("default")

-- Safe commands
local check_safe = perms.check("exec", "echo 'olá'")
T("Default: auto-permite comandos seguros (echo)", check_safe.allowed == true)

-- Comandos não mapeados pedem permissão
local check_ask = perms.check("exec", "sort -r")
T("Default: pede permissão para comando desconhecido", check_ask.allowed == false and check_ask.reason == "ask")

-- Adicionando regra temporária na sessão
perms.add_rule("sort *", "allow", false) -- em memória
local check_rule_ok = perms.check("exec", "sort -r")
T("Default: permite comando que bate com regra de sessão adicionada", check_rule_ok.allowed == true)

-- Removendo regra temporária
perms.remove_rule("sort *", "allow", false)
local check_rule_removed = perms.check("exec", "sort -r")
T("Default: volta a pedir permissão após remover a regra", check_rule_removed.allowed == false and check_rule_removed.reason == "ask")

-- Adicionando regra permanente (persistida)
perms.add_rule("npm run *", "allow", true) -- persistida no config.json
local check_persist_ok = perms.check("exec", "npm run build")
T("Default: permite comando que bate com regra persistente", check_persist_ok.allowed == true)

-- Comandos proibidos por regra deny
perms.add_rule("rm -rf *", "deny", true)
local check_deny = perms.check("exec", "rm -rf /tmp/teste")
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
print("\n" .. string.rep("═", 60))
print(string.format("RESULTADO DOS TESTES DE PERMISSÕES BASH: %d passaram, %d falharam", pass, fail))
print(string.rep("═", 60))

if fail > 0 then
  os.exit(1)
end
