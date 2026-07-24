-- agent/hooks/bash_patterns/suggest.lua — Geração de padrões sugeridos (Estilo Claude Code).
local M = {}

function M.get_suggested_pattern(cmd)
  local tokens = {}
  for t in cmd:gmatch("%S+") do
    if not t:match("^[%w_]+=") then
      tokens[#tokens + 1] = t
    end
  end
  if #tokens == 0 then return "" end

  local runners = {
    git = true, npm = true, pnpm = true, yarn = true, bun = true,
    cargo = true, python = true, pip = true, go = true, docker = true,
    bash = true, sh = true, lua = true, ["lua5.4"] = true, node = true
  }

  local first = tokens[1]:lower()
  if runners[first] and tokens[2] then
    return tokens[1] .. " " .. tokens[2] .. " *"
  else
    return tokens[1] .. " *"
  end
end

return M
