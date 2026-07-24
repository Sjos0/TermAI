-- agent/hooks/bash_patterns.lua — Permissões granulares para exec (Padrão Fachada).
local M = {}

local rules = require("agent.hooks.bash_patterns.rules")
local ui    = require("agent.hooks.bash_patterns.ui")

M.last_approval_type = nil

function M.matches(cmd)
  local ok, err = rules.matches(cmd)
  if ok then
    M.last_approval_type = "AUTO_APPROVED"
  end
  return ok, err
end

function M.ask_user(cmd, failed_sub)
  local ok = ui.ask_user(cmd, failed_sub)
  M.last_approval_type = ui.last_approval_type or M.last_approval_type
  return ok
end

M.add_pattern    = rules.add_pattern
M.remove_pattern = rules.remove_pattern
M.reset          = rules.reset
M.list           = rules.list

return M
