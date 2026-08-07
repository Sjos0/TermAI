-- agent/hooks/bash_patterns/suggest.lua — Geração de padrões sugeridos (Estilo Claude Code).
-- v2: ignora comentários, continuações \, e fragmentos sem comando real.
local M = {}

function M.get_suggested_pattern(cmd)
  if not cmd or cmd == "" then return "" end

  local parser = require("agent.hooks.bash_patterns.parser")

  local subs = parser.extract_subcommands(cmd)
  local target = (#subs > 0) and subs[1] or cmd

  target = target:gsub("^%s*#+[^\n]*\n?", "")
  target = target:gsub("^%s*\\%s*", "")
  target = parser.strip_leading_assignments(target)
  target = target:match("^%s*(.-)%s*$") or target

  if target == "" then return "" end

  local tokens = {}
  for t in target:gmatch("%S+") do
    if t:match("%w") then
      tokens[#tokens + 1] = t
    end
  end
  if #tokens == 0 then return "" end

  local runners = {
    git = true, npm = true, pnpm = true, yarn = true, bun = true,
    cargo = true, python = true, pip = true, go = true, docker = true,
    bash = true, sh = true, lua = true, ["lua5.4"] = true, node = true,
    curl = true, wget = true, ssh = true, scp = true,
  }

  local first = tokens[1]:lower()
  if not first:match("^[%w_.%-]+$") then
    return ""
  end

  if runners[first] and tokens[2] and tokens[2]:match("%w") then
    return tokens[1] .. " " .. tokens[2] .. " *"
  end
  return tokens[1] .. " *"
end

return M
