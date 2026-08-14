-- tests/permissions_rules_spec.lua — Testes unitários do módulo rules (PR #33 / Issue #26)
-- ATENÇÃO: toca config.json; sempre limpa o que cria.
package.path = "./?.lua;./?/init.lua;" .. package.path

local rules = require("tools.exec.permissions.rules")
local session = require("tools.exec.permissions.session")
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

local function sec(title)
  print("\n=== " .. title .. " ===")
end

local function snapshot_bash_rules()
  local cfg = config_mod.load()
  local snap = { allow = {}, deny = {} }
  if cfg.bashRules then
    for _, p in ipairs(cfg.bashRules.allow or {}) do table.insert(snap.allow, p) end
    for _, p in ipairs(cfg.bashRules.deny or {}) do table.insert(snap.deny, p) end
  end
  return snap
end

local function restore_bash_rules(snap)
  local cfg = config_mod.load()
  cfg.bashRules = cfg.bashRules or {}
  cfg.bashRules.allow = snap.allow
  cfg.bashRules.deny = snap.deny
  config_mod.save(cfg)
end

local function clear_session_rules()
  session.set_rules("allow", {})
  session.set_rules("deny", {})
end

local orig = snapshot_bash_rules()

-- ============================================================================
-- 1. SAFE_COMMANDS
-- ============================================================================
sec("1. SAFE_COMMANDS")

T("contém echo", rules.SAFE_COMMANDS.echo == true)
T("contém ls", rules.SAFE_COMMANDS.ls == true)
T("contém lua5.4", rules.SAFE_COMMANDS["lua5.4"] == true)
T("contém git", rules.SAFE_COMMANDS.git == true)
T("contém cat", rules.SAFE_COMMANDS.cat == true)
T("NÃO contém rm", rules.SAFE_COMMANDS.rm == nil)
T("NÃO contém mv", rules.SAFE_COMMANDS.mv == nil)
T("NÃO contém rmdir", rules.SAFE_COMMANDS.rmdir == nil)

-- ============================================================================
-- 2. add / remove session (não grava config)
-- ============================================================================
sec("2. add/remove session (não-persistente)")

clear_session_rules()
local before = snapshot_bash_rules()

rules.add("echo *", "allow", false)
local sess_allow = session.get_rules("allow")
T("add session allow grava na sessão", #sess_allow == 1 and sess_allow[1] == "echo *")

local after = snapshot_bash_rules()
T("add session NÃO altera config.json", #after.allow == #before.allow and #after.deny == #before.deny)

rules.add("rm *", "deny", false)
T("add session deny", #session.get_rules("deny") == 1)

rules.add("ECHO *", "allow", false)
T("dedupe case-insensitive (session)", #session.get_rules("allow") == 1)

rules.remove("echo *", "allow", false)
T("remove session allow", #session.get_rules("allow") == 0)

rules.remove("item_inexistente_xyz", "deny", false)
T("remove de item inexistente não crasha", #session.get_rules("deny") == 1)

rules.remove("rm *", "deny", false)
T("remove session deny", #session.get_rules("deny") == 0)

-- ============================================================================
-- 3. add / remove persistent (grava config.json)
-- ============================================================================
sec("3. add/remove persistent")

restore_bash_rules({ allow = {}, deny = {} })
clear_session_rules()

rules.add("sort *", "allow", true)
local cfg1 = config_mod.load()
local found = false
for _, p in ipairs(cfg1.bashRules.allow or {}) do
  if p:lower() == "sort *" then found = true; break end
end
T("add persistent grava em config.json bashRules.allow", found == true)

rules.add("SORT *", "allow", true)
local cfg2 = config_mod.load()
local count = 0
for _, p in ipairs(cfg2.bashRules.allow or {}) do
  if p:lower() == "sort *" then count = count + 1 end
end
T("dedupe case-insensitive (persistent)", count == 1)

rules.add("rm -rf *", "deny", true)
local cfg3 = config_mod.load()
local found_deny = false
for _, p in ipairs(cfg3.bashRules.deny or {}) do
  if p:lower() == "rm -rf *" then found_deny = true; break end
end
T("add persistent deny grava em bashRules.deny", found_deny == true)

rules.remove("sort *", "allow", true)
local cfg4 = config_mod.load()
local still = false
for _, p in ipairs(cfg4.bashRules.allow or {}) do
  if p:lower() == "sort *" then still = true; break end
end
T("remove persistent remove de config.json", still == false)

rules.remove("item_inexistente_xyz", "allow", true)
T("remove persistent de item inexistente não crasha", true)

rules.remove("rm -rf *", "deny", true)
local cfg5 = config_mod.load()
local still_deny = false
for _, p in ipairs(cfg5.bashRules.deny or {}) do
  if p:lower() == "rm -rf *" then still_deny = true; break end
end
T("remove persistent deny limpa config", still_deny == false)

-- Cleanup final
restore_bash_rules(orig)
clear_session_rules()

print("\nRESULTADO: " .. pass .. " passaram, " .. fail .. " falharam")
if fail > 0 then os.exit(1) end
