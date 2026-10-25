-- tests/permissions_check_spec/04_10_comando_desconhecido.lua — parte de permissions_check_spec.lua (ver fachada).
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

end

return M
