-- tools/exec/permissions/rules.lua — Add/remove de regras allow/deny
-- Persistente (config.json) ou temporária (sessão via session.lua).
local config_mod = require("config")
local session = require("tools.exec.permissions.session")

local M = {}

-- SAFE_COMMANDS padrão para auto-aprovação rápida
M.SAFE_COMMANDS = {
  cd = true, ls = true, echo = true, cat = true, mkdir = true,
  chmod = true, grep = true, find = true, luac = true, lua = true,
  ["lua5.4"] = true, python = true, node = true, du = true, df = true,
  uptime = true, date = true, wc = true, ps = true, tail = true,
  head = true, awk = true, clear = true, pgrep = true, test = true,
  git = true
}

-- Adiciona uma regra allow/deny persistente ou temporária na sessão
function M.add(pattern, behavior, persistent)
  if persistent then
    local cfg = {}
    pcall(function() cfg = config_mod.load() end)
    cfg.bashRules = cfg.bashRules or {}
    cfg.bashRules[behavior] = cfg.bashRules[behavior] or {}

    local lower = pattern:lower()
    local exists = false
    for _, p in ipairs(cfg.bashRules[behavior]) do
      if p:lower() == lower then exists = true; break end
    end
    if not exists then
      table.insert(cfg.bashRules[behavior], pattern)
      pcall(function() config_mod.save(cfg) end)
    end
  else
    local list = session.get_rules(behavior)
    -- Cópia mutável: get_rules pode retornar {} literal
    local new_list = {}
    for _, p in ipairs(list) do table.insert(new_list, p) end

    local exists = false
    local lower = pattern:lower()
    for _, p in ipairs(new_list) do
      if p:lower() == lower then exists = true; break end
    end
    if not exists then
      table.insert(new_list, pattern)
      session.set_rules(behavior, new_list)
    end
  end
end

-- Remove uma regra allow/deny
function M.remove(pattern, behavior, persistent)
  if persistent then
    local cfg = {}
    pcall(function() cfg = config_mod.load() end)
    if cfg.bashRules and cfg.bashRules[behavior] then
      local lower = pattern:lower()
      local new_rules = {}
      for _, p in ipairs(cfg.bashRules[behavior]) do
        if p:lower() ~= lower then
          table.insert(new_rules, p)
        end
      end
      cfg.bashRules[behavior] = new_rules
      pcall(function() config_mod.save(cfg) end)
    end
  else
    local list = session.get_rules(behavior)
    local lower = pattern:lower()
    local new_rules = {}
    for _, p in ipairs(list) do
      if p:lower() ~= lower then
        table.insert(new_rules, p)
      end
    end
    session.set_rules(behavior, new_rules)
  end
end

return M
