-- tests/permissions_check_spec/02_4_hooks_permissions_config.lua — parte de permissions_check_spec.lua (ver fachada).
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
end

return M
