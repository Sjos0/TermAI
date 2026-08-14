-- tools/exec/permissions/matcher.lua — Matching de curingas e regras bash
local M = {}

-- Converte curingas de shell (ex: "sort *") para padrões Lua flexíveis e robustos
function M.wildcard_to_pattern(wildcard)
  local has_trailing_space_star = wildcard:match("%s%*$")
  if has_trailing_space_star then
    local base = wildcard:sub(1, #wildcard - 2)
    local p = base:gsub("[%^%$%(%)%%%.%[%]%+%-%?]", "%%%1")
    return "^" .. p .. "$"
  else
    local p = wildcard:gsub("[%^%$%(%)%%%.%[%]%+%-%?]", "%%%1")
    p = p:gsub("%*", ".*")
    return "^" .. p .. "$"
  end
end

-- Verifica se um comando específico bate com um padrão/regra (com ou sem curinga)
function M.matches_rule(cmd, pattern)
  cmd = cmd:lower():match("^%s*(.-)%s*$") or cmd:lower()
  pattern = pattern:lower():match("^%s*(.-)%s*$") or pattern:lower()

  if pattern == "" then return false end

  -- Se for com prefixo de dois pontos (ex: rm:*)
  local prefix = pattern:match("^(.-):%*$")
  if prefix then
    prefix = prefix:match("^%s*(.-)%s*$") or prefix
    return cmd == prefix or cmd:sub(1, #prefix + 1) == prefix .. " "
  end

  -- Se terminar com " *", tratamos o espaço e argumentos como opcionais de forma extremamente robusta
  if pattern:match("%s%*$") then
    local base = pattern:sub(1, #pattern - 2):match("^%s*(.-)%s*$")
    return cmd == base or cmd:sub(1, #base + 1) == base .. " "
  end

  if pattern:find("*", 1, true) then
    local pat = pattern:gsub("[%^%$%(%)%%%.%[%]%+%-%?]", "%%%1")
    pat = pat:gsub("%*", ".*")
    pat = "^" .. pat .. "$"
    return cmd:match(pat) ~= nil
  end

  return cmd == pattern
end

return M
