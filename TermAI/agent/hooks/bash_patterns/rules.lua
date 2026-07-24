-- agent/hooks/bash_patterns/rules.lua — Verificação de comandos e whitelists/blacklists.
local config_mod = require("config")
local parser = require("agent.hooks.bash_patterns.parser")

local M = {}

local SAFE_COMMANDS = {
  cd = true, ls = true, echo = true, cat = true, mkdir = true,
  chmod = true, grep = true, find = true, luac = true, lua = true,
  ["lua5.4"] = true, python = true, node = true, du = true, df = true,
  uptime = true, date = true, wc = true, ps = true, tail = true,
  head = true, awk = true, clear = true, pgrep = true, test = true,
  git = true
}

local DANGER_PATTERNS = {
  "%f[%w]rm%f[%W]",
  "%f[%w]rmdir%f[%W]",
  "%f[%w]dd%f[%W]",
  "%f[%w]mkfs%f[%W]",
  "%f[%w]shred%f[%W]"
}

local function matches_rule(cmd, pattern)
  cmd = cmd:lower():match("^%s*(.-)%s*$") or cmd:lower()
  pattern = pattern:lower():match("^%s*(.-)%s*$") or pattern:lower()

  local prefix = pattern:match("^(.-):%*$")
  if prefix then
    prefix = prefix:match("^%s*(.-)%s*$") or prefix
    return cmd == prefix or cmd:sub(1, #prefix + 1) == prefix .. " "
  end

  if pattern:find("*", 1, true) then
    local pat = parser.wildcard_to_pattern(pattern)
    return cmd:match(pat) ~= nil
  end

  return cmd == pattern
end

function M.matches(cmd)
  local cfg = config_mod.load()
  local patterns = (cfg.hooks and cfg.hooks.bash_patterns) or {}

  local subcommands = parser.extract_subcommands(cmd)
  if #subcommands == 0 then return false, nil end

  local MAX_SUBCOMMANDS = 15
  if #subcommands > MAX_SUBCOMMANDS then
    return false, cmd
  end

  for _, sub in ipairs(subcommands) do
    local sub_lower = sub:lower()
    for _, danger in ipairs(DANGER_PATTERNS) do
      if sub_lower:match(danger) then
        return false, sub
      end
    end
  end

  for _, sub in ipairs(subcommands) do
    local sub_trim = (sub:match("^%s*(.-)%s*$") or sub):lower()
    local primary = sub_trim:match("^%s*(%S+)") or ""
    local matched_sub = false

    if SAFE_COMMANDS[primary] then
      matched_sub = true
    else
      for _, p in ipairs(patterns) do
        if matches_rule(sub_trim, p) then
          matched_sub = true
          break
        end
      end
    end

    if not matched_sub then
      return false, sub
    end
  end

  return true, "padrões aprovados"
end

function M.add_pattern(pattern)
  local cfg = config_mod.load()
  if not cfg.hooks then cfg.hooks = {} end
  if not cfg.hooks.bash_patterns then cfg.hooks.bash_patterns = {} end
  local lower = pattern:lower()
  for _, p in ipairs(cfg.hooks.bash_patterns) do
    if p:lower() == lower then return end
  end
  cfg.hooks.bash_patterns[#cfg.hooks.bash_patterns + 1] = pattern
  config_mod.save(cfg)
end

function M.remove_pattern(pattern)
  local cfg = config_mod.load()
  if not cfg.hooks or not cfg.hooks.bash_patterns then return end
  local lower = pattern:lower()
  local new = {}
  for _, p in ipairs(cfg.hooks.bash_patterns) do
    if p:lower() ~= lower then new[#new + 1] = p end
  end
  cfg.hooks.bash_patterns = new
  config_mod.save(cfg)
end

function M.reset()
  local cfg = config_mod.load()
  if not cfg.hooks then cfg.hooks = {} end
  cfg.hooks.bash_patterns = {}
  config_mod.save(cfg)
end

function M.list()
  local cfg = config_mod.load()
  return (cfg.hooks and cfg.hooks.bash_patterns) or {}
end

return M
