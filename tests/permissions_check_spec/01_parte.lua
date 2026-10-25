-- tests/permissions_check_spec/01_parte.lua — parte de permissions_check_spec.lua (ver fachada).
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
end

return M
