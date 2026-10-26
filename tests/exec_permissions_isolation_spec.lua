-- tests/exec_permissions_isolation_spec.lua — regressão issue #129
-- Prova que config "de usuário" (ex.: allow "sort *") não contamina matcher/check
-- quando sandbox + config_fake estão instalados antes dos requires de produção.

package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local harness = require("tests.helpers.harness")
local pass, fail = 0, 0
local function T(name, ok, detail)
  if ok then
    pass = pass + 1
    print("  ✅ " .. name)
  else
    fail = fail + 1
    print("  ❌ " .. name .. (detail and (" — " .. tostring(detail)) or ""))
  end
end

-- Ordem obrigatória (igual ao exec_permissions_spec): sandbox → fake → requires
local sandbox = require("tests.helpers.config_sandbox")
local caminho = sandbox.install()
T("sandbox PATH temporário",
  type(caminho) == "string" and caminho:find("termai_test_config", 1, true) ~= nil)

local home = os.getenv("HOME") or ""
T("sandbox não aponta para ~/.TermAI/config.json",
  caminho ~= (home .. "/.TermAI/config.json")
  and not caminho:find("/.TermAI/config.json", 1, true))

local store = require("tests.helpers.config_fake").install()
-- Regra tóxica que historicamente quebrava o spec quando lia o config real
store.bashRules = { allow = { "sort *" }, deny = {} }
store.hooks = { permissions = {} }

local perms = require("tools.exec.permissions")

T("matches_rule: sort -n bate com sort *",
  perms.matches_rule("sort -n", "sort *") == true)

T("matches_rule: ls não bate com sort *",
  perms.matches_rule("ls -la", "sort *") == false)

perms.set_mode("bypass")
local r = perms.check("Exec", "rm -rf /")
T("bypass: allowed=true", type(r) == "table" and r.allowed == true, r and r.reason)

perms.set_mode("default")
-- Com fake isolado e sem regras de sessão forçando allow em rm, check deve pedir/ask ou deny
-- (não deve herdar allow de um config real do usuário)
local r2 = perms.check("Exec", "rm -rf /tmp/x")
T("default+fake: rm não vem allowed por contaminação de config real",
  type(r2) == "table" and r2.allowed ~= true,
  r2 and (r2.reason or "nil"))

-- Fonte: fachada e partes instalam isolamento
local facade = assert(io.open("tests/exec_permissions_spec.lua", "r")):read("*a")
T("fachada instala config_sandbox", facade:find("config_sandbox") ~= nil)

local p1 = assert(io.open("tests/exec_permissions_spec/01_parte.lua", "r")):read("*a")
T("01_parte instala config_fake", p1:find("config_fake") ~= nil)

local p2 = assert(io.open("tests/exec_permissions_spec/02_parte.lua", "r")):read("*a")
T("02_parte instala config_fake", p2:find("config_fake") ~= nil)

local fake_src = assert(io.open("tests/helpers/config_fake.lua", "r")):read("*a")
T("config_fake documenta contaminação",
  fake_src:find("config.json", 1, true) ~= nil)

print(string.format("\nRESULTADO isolation #129: %d passaram, %d falharam", pass, fail))
if fail > 0 then os.exit(1) end
print("PASS  exec_permissions_isolation_spec")
