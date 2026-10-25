-- tests/permissions_check_spec/03_7_deny_prioridade_sobre_al.lua — parte de permissions_check_spec.lua (ver fachada).
local harness = require("tests.helpers.harness")

local M = {}

function M.run()

  local check = require("tools.exec.permissions.check")
  local mode = require("tools.exec.permissions.mode")
  local session = require("tools.exec.permissions.session")
  local rules = require("tools.exec.permissions.rules")
  local config_mod = require("config")

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
end

return M
