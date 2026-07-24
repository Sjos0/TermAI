-- tokenizer.lua — Normalização e tokenização de queries de busca.
local M = {}

local function tokenize(query)
  local tokens = {}
  local seen   = {}
  for word in query:gmatch("%S+") do
    local t = word:lower():match("^%s*(.-)%s*$")
    -- Remove pontuação simples das bordas
    t = t:gsub("^[%p]+", ""):gsub("[%p]+$", "")
    if t ~= "" and not seen[t] then
      seen[t] = true
      tokens[#tokens + 1] = t
    end
  end
  return tokens
end

M.tokenize = tokenize
return M
