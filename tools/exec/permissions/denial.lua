-- tools/exec/permissions/denial.lua — Denial tracking (contagem de rejeições)
local config_mod = require("config")

local M = {}

local session_denials = {}

-- Registra rejeição da ferramenta ou regra para Denial Tracking
-- Retorna true se atingiu o threshold para oferecer bloqueio
function M.increment(pattern_or_tool)
  session_denials[pattern_or_tool] = (session_denials[pattern_or_tool] or 0) + 1

  local cfg = {}
  pcall(function() cfg = config_mod.load() end)
  local threshold = cfg.permissions and cfg.permissions.denialThreshold or 3

  if session_denials[pattern_or_tool] >= threshold then
    session_denials[pattern_or_tool] = 0 -- reseta para a próxima vez
    return true
  end
  return false
end

function M.get_count(pattern_or_tool)
  return session_denials[pattern_or_tool] or 0
end

function M.reset(pattern_or_tool)
  session_denials[pattern_or_tool] = 0
end

return M
