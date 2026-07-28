-- tests/web_fetch_security_spec.lua
-- Testes de segurança para a ferramenta web_fetch (Command Injection e SSRF)
package.path = "./?.lua;./?/init.lua;" .. package.path

local fetcher = require("tools.web_fetch.fetcher")

local pass, fail = 0, 0
local function TEST(name, ok, detail)
  if ok then
    pass = pass + 1
  else
    fail = fail + 1
    print("  FAIL: " .. name .. (detail and (" — " .. detail) or ""))
  end
end

print("\n=== Testes de Segurança: web_fetch (Command Injection & SSRF) ===\n")

-- 1: URLs Legítimas e Seguras (devem ser processadas)
-- Para evitar chamadas de rede reais durante o teste de segurança isolado,
-- nós mockamos check_lynx e as chamadas reais se necessário, ou testamos apenas a validação inicial.
-- Mas neste caso, queremos validar todo o fluxo de escape da validação de segurança.

local orig_popen = io.popen
local popen_called = false
local popen_cmd = ""

io.popen = function(cmd)
  popen_called = true
  popen_cmd = cmd
  return {
    read = function(self, mode) return "Conteudo Mockado" end,
    close = function(self) end
  }
end

-- 1.1 URL segura padrão
popen_called = false
local res = fetcher.run("https://example.com/page")
TEST("URL padrão segura é aceita", popen_called == true, "Deveria ter chamado o shell para buscar")
TEST("Resposta contém conteúdo mockado", res:find("Conteudo Mockado") ~= nil)

-- 1.2 URL segura com parâmetros de query complexos (incluindo &, =, ?)
popen_called = false
local res_complex = fetcher.run("https://example.com/search?q=lua&lang=pt_br&sort=desc")
TEST("URL com múltiplos parâmetros & e = é aceita", popen_called == true, "Parâmetros legítimos foram bloqueados incorretamente")
TEST("Resposta complexa contém conteúdo mockado", res_complex:find("Conteudo Mockado") ~= nil)


-- 2: URLs Maliciosas (devem ser rejeitadas)

-- 2.1 Injeção com Aspas Duplas
popen_called = false
local res_inj1 = fetcher.run('https://example.com/page";rm -rf /;"')
TEST("Injeção com aspas duplas é bloqueada", popen_called == false, "Vulnerável a aspas duplas!")
TEST("Mensagem de erro de segurança apropriada", res_inj1:find("potencialmente inseguros") ~= nil)

-- 2.2 Injeção com Cifrão e Subshell
popen_called = false
local res_inj2 = fetcher.run('https://example.com/$(whoami)')
TEST("Injeção com cifrão/subshell é bloqueada", popen_called == false, "Vulnerável a cifrão!")
TEST("Mensagem de erro de segurança apropriada (cifrão)", res_inj2:find("potencialmente inseguros") ~= nil)

-- 2.3 Injeção com Crase e Subshell
popen_called = false
local res_inj3 = fetcher.run('https://example.com/`id`')
TEST("Injeção com crase/subshell é bloqueada", popen_called == false, "Vulnerável a crase!")
TEST("Mensagem de erro de segurança apropriada (crase)", res_inj3:find("potencialmente inseguros") ~= nil)

-- 2.4 Injeção com Barra Invertida (Escape)
popen_called = false
local res_inj4 = fetcher.run('https://example.com/some\\path')
TEST("Injeção com barra invertida é bloqueada", popen_called == false, "Vulnerável a barra invertida!")
TEST("Mensagem de erro de segurança apropriada (barra invertida)", res_inj4:find("potencialmente inseguros") ~= nil)

-- 2.5 Injeção com Quebra de Linha (Newline)
popen_called = false
local res_inj5 = fetcher.run("https://example.com/path\nid")
TEST("Injeção com quebra de linha é bloqueada", popen_called == false, "Vulnerável a quebra de linha!")
TEST("Mensagem de erro de segurança apropriada (nova linha)", res_inj5:find("potencialmente inseguros") ~= nil)

-- 2.6 Injeção com Carriage Return
popen_called = false
local res_inj6 = fetcher.run("https://example.com/path\rid")
TEST("Injeção com carriage return é bloqueada", popen_called == false, "Vulnerável a carriage return!")
TEST("Mensagem de erro de segurança apropriada (carriage return)", res_inj6:find("potencialmente inseguros") ~= nil)


-- 3: Testes de SSRF Existentes (devem continuar funcionando)
local res_ssrf = fetcher.run("https://localhost/api")
TEST("Bloqueio SSRF para localhost continua ativo", res_ssrf:find("Bloqueio SSRF") ~= nil)


-- Restaurar popen
io.popen = orig_popen

print(string.format(
  "\n══ RESULTADO: %d passaram, %d falharam (total: %d) ══",
  pass, fail, pass + fail))

if fail > 0 then
  os.exit(1)
end
