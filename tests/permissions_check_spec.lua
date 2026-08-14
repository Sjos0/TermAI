-- tests/permissions_check_spec.lua — Testes unitários do módulo check (PR #33 / Issue #26)
-- ATENÇÃO: depende de config.json, session e parser. Sempre restaura estado.
package.path = "./?.lua;./?/init.lua;" .. package.path

local check = require("tools.exec.permissions.check")
local mode = require("tools.exec.permissions.mode")
local session = require("tools.exec.permissions.session")
local rules = require("tools.exec.permissions.rules")
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

local orig_mode = mode.get()

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

local function clear_session()
  session.set_status("Exec", nil)
  session.set_status("Read", nil)
  session.set_status("Write", nil)
  session.set_rules("allow", {})
  session.set_rules("deny", {})
end

local function clear_hooks_permissions()
  local cfg = config_mod.load()
  cfg.hooks = cfg.hooks or {}
  cfg.hooks.permissions = {}
  config_mod.save(cfg)
end

local orig_rules = snapshot_bash_rules()
clear_session()
clear_hooks_permissions()
mode.set("default")

-- ============================================================================
-- 1. Modo bypass
-- ============================================================================
sec("1. Modo bypass")

mode.set("bypass")
local r = check.check("Exec", "rm -rf /")
T("bypass → allowed=true", r.allowed == true)
T("bypass reason menciona Bypass", type(r.reason) == "string" and r.reason:lower():find("bypass") ~= nil)

-- ============================================================================
-- 2. Modo acceptEdits
-- ============================================================================
sec("2. Modo acceptEdits")

mode.set("acceptEdits")
local r_read = check.check("Read", "qualquer coisa")
T("acceptEdits + não-Exec → allowed", r_read.allowed == true)

local r_exec = check.check("Exec", "echo hello")
T("acceptEdits + Exec safe → allowed (SAFE_COMMANDS)", r_exec.allowed == true)

local r_ask = check.check("Exec", "rm -rf /tmp/x")
T("acceptEdits + Exec não-safe sem regra → reason ask", r_ask.allowed == false and r_ask.reason == "ask")

-- ============================================================================
-- 3. Session status blocked / always
-- ============================================================================
sec("3. Session status")

mode.set("default")
clear_session()

session.set_status("Exec", "blocked")
local r_b = check.check("Exec", "echo hello")
T("session blocked → allowed=false reason=blocked", r_b.allowed == false and r_b.reason == "blocked")

session.set_status("Exec", "always")
local r_a = check.check("Exec", "rm -rf /")
T("session always → allowed=true", r_a.allowed == true)

session.set_status("Exec", nil)

-- ============================================================================
-- 4. Config hooks.permissions blocked / always
-- ============================================================================
sec("4. hooks.permissions (config)")

clear_session()
local cfg = config_mod.load()
cfg.hooks = cfg.hooks or {}
cfg.hooks.permissions = { Exec = "blocked" }
config_mod.save(cfg)

local r_hb = check.check("Exec", "echo hello")
T("hooks.permissions blocked → blocked", r_hb.allowed == false and r_hb.reason == "blocked")

cfg = config_mod.load()
cfg.hooks.permissions = { Exec = "always" }
config_mod.save(cfg)
local r_ha = check.check("Exec", "rm -rf /")
T("hooks.permissions always → allowed", r_ha.allowed == true)

clear_hooks_permissions()

-- ============================================================================
-- 5. Não-Exec sem status → ask
-- ============================================================================
sec("5. Não-Exec sem status")

clear_session()
local r_ne = check.check("Write", "file.txt")
T("não-Exec sem status → reason=ask", r_ne.allowed == false and r_ne.reason == "ask")

-- ============================================================================
-- 6. Comando nil / vazio / sem subcomandos
-- ============================================================================
sec("6. Comando nil/vazio/sem subcomandos")

clear_session()
mode.set("default")

local r_nil = check.check("Exec", nil)
T("command nil → allowed", r_nil.allowed == true)

local r_empty = check.check("Exec", "")
T("command vazio → allowed", r_empty.allowed == true)

local r_ws = check.check("Exec", "   ")
T("command só espaços → allowed", r_ws.allowed == true)

-- ============================================================================
-- 7. Deny tem prioridade sobre allow (persistente e sessão)
-- ============================================================================
sec("7. Deny prioridade sobre allow")

clear_session()
restore_bash_rules({ allow = {}, deny = {} })

rules.add("rm *", "allow", true)
rules.add("rm *", "deny", true)
local r_deny = check.check("Exec", "rm -f /tmp/x")
T("deny persistente vence allow persistente", r_deny.allowed == false and r_deny.reason == "deny")

restore_bash_rules({ allow = {}, deny = {} })
rules.add("rm *", "allow", false)
rules.add("rm *", "deny", false)
local r_deny_s = check.check("Exec", "rm -f /tmp/x")
T("deny sessão vence allow sessão", r_deny_s.allowed == false and r_deny_s.reason == "deny")

clear_session()
restore_bash_rules({ allow = {}, deny = {} })

-- ============================================================================
-- 8. SAFE_COMMANDS → allowed
-- ============================================================================
sec("8. SAFE_COMMANDS")

local r_safe = check.check("Exec", "echo hello")
T("echo (SAFE) → allowed", r_safe.allowed == true)

local r_ls = check.check("Exec", "ls -la")
T("ls (SAFE) → allowed", r_ls.allowed == true)

-- ============================================================================
-- 9. Allow rule (persistente e sessão)
-- ============================================================================
sec("9. Allow rules")

clear_session()
restore_bash_rules({ allow = {}, deny = {} })

rules.add("sort *", "allow", true)
local r_allow_p = check.check("Exec", "sort -rn file.txt")
T("allow persistente → allowed", r_allow_p.allowed == true)

restore_bash_rules({ allow = {}, deny = {} })
rules.add("sort *", "allow", false)
local r_allow_s = check.check("Exec", "sort -rn file.txt")
T("allow sessão → allowed", r_allow_s.allowed == true)

clear_session()
restore_bash_rules({ allow = {}, deny = {} })

-- ============================================================================
-- 10. Comando desconhecido → ask + unknown_cmd
-- ============================================================================
sec("10. Comando desconhecido")

local r_unk = check.check("Exec", "nome_que_nao_existe_xyz_999 arg1")
T("desconhecido → reason=ask", r_unk.allowed == false and r_unk.reason == "ask")
T("desconhecido → unknown_cmd=true", r_unk.unknown_cmd == true)

local r_known_nonsafe = check.check("Exec", "rm -f /tmp/x")
T("conhecido não-safe sem regra → ask (unknown_cmd=false ou nil)", r_known_nonsafe.allowed == false and r_known_nonsafe.reason == "ask" and r_known_nonsafe.unknown_cmd ~= true)

-- Cleanup final
mode.set(orig_mode)
restore_bash_rules(orig_rules)
clear_session()
clear_hooks_permissions()

print("\nRESULTADO: " .. pass .. " passaram, " .. fail .. " falharam")
if fail > 0 then os.exit(1) end
