-- agent/hooks/permissions.lua — DEPRECADO: Use tools/exec/permissions.lua em seu lugar.
-- Mantido por razões de compatibilidade.
local perms_new = require("tools.exec.permissions")
local config_mod = require("config")

local M = {}

M.last_approval_type = nil

function M.get(tool_name)
  -- Mantém compatibilidade delegando ao novo gerenciador
  local mode = perms_new.get_mode()
  if mode == "bypass" then return "always" end

  local sess_status = perms_new.get_session_status(tool_name)
  if sess_status then return sess_status end

  local cfg = config_mod.load()
  local perms = cfg.hooks and cfg.hooks.permissions
  if perms and perms[tool_name] then
    return perms[tool_name]
  end
  return "ask"
end

function M.set(tool_name, status)
  local cfg = config_mod.load()
  if not cfg.hooks             then cfg.hooks             = {} end
  if not cfg.hooks.permissions then cfg.hooks.permissions = {} end
  cfg.hooks.permissions[tool_name] = status
  config_mod.save(cfg)
end

function M.ask_user(tool_name, tool_arg)
  local ui = require("tools.exec.permissions_ui")
  local choice, pat = ui.show_dialog(tool_name, tool_arg, nil, nil)
  if choice == "once" then
    M.last_approval_type = "APPROVED_ONCE"
    return true
  elseif choice == "always" then
    M.last_approval_type = "PERMANENTLY_APPROVED"
    M.set(tool_name, "always")
    return true
  elseif choice == "block" then
    M.last_approval_type = "CANCELLED"
    M.set(tool_name, "blocked")
    return false
  else
    M.last_approval_type = "CANCELLED"
    return false
  end
end

return M
