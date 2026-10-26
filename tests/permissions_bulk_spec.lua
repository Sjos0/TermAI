-- tests/permissions_bulk_spec.lua — Ação em lote "Sempre para todas" (permissions_bulk)
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
require("tests.helpers.config_sandbox").install()

local bulk       = require("commands.config.menus.permissions_bulk")
local perms      = require("agent.hooks.permissions")
local config_mod = require("config")

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

print("\n=== 1. Confirmação ===")
T("'s', 'S' e 'sim' confirmam", bulk.is_confirmed("s") and bulk.is_confirmed("S") and bulk.is_confirmed("  sim  "))
T("vazio, 'n' e nil cancelam", not bulk.is_confirmed("") and not bulk.is_confirmed("n") and not bulk.is_confirmed(nil))

print("\n=== 2. Liberação em lote ===")
perms.set("Exec", "blocked")
perms.set("Read", "ask")
perms.set("Edit", "ask")
local nomes = { "Exec", "Read", "Edit", "Grep" }
local liberadas, preservadas = bulk.allow_all(perms, nomes)
T("ask vira always", perms.get("Read") == "always" and perms.get("Edit") == "always")
T("ausente vira always", perms.get("Grep") == "always")
T("blocked é preservado", perms.get("Exec") == "blocked")
T("contagem: 3 liberadas", liberadas == 3, "liberadas=" .. tostring(liberadas))
T("lista de preservadas tem só Exec", #preservadas == 1 and preservadas[1] == "Exec")

print("\n=== 3. Deny do bash continua valendo ===")
local cfg = config_mod.load()
cfg.bashRules = { allow = {}, deny = { "rm -rf *" } }
config_mod.save(cfg)
bulk.allow_all(perms, nomes)
cfg = config_mod.load()
T("regra deny intacta após lote", cfg.bashRules and cfg.bashRules.deny and cfg.bashRules.deny[1] == "rm -rf *")

print(string.format("\nRESULTADO LOTE DE PERMISSÕES: %d passaram, %d falharam", pass, fail))
if fail > 0 then os.exit(1) end
