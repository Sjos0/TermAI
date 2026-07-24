-- tools/error_feedback/fuzzy_match.lua
-- Levenshtein simplificado para sugerir nomes de ferramentas proximos.
local M = {}

local function levenshtein(a, b)
  local la, lb = #a, #b
  if la == 0 then return lb end
  if lb == 0 then return la end
  local row = {}
  for j = 0, lb do row[j] = j end
  for i = 1, la do
    local prev = i
    for j = 1, lb do
      local cost = (a:sub(i,i) == b:sub(j,j)) and 0 or 1
      local val  = math.min(row[j] + 1, prev + 1, row[j-1] + cost)
      row[j-1]   = prev
      prev       = val
    end
    row[lb] = prev
  end
  return row[lb]
end

-- Retorna: best_match (string ou nil), distance (numero).
-- Retorna nil se distancia > THRESHOLD (match fraco demais para sugerir).
function M.find_closest(input, candidates)
  if not input or input == "" then return nil, math.huge end
  local THRESHOLD = 5
  local input_low = input:lower()
  local best, best_dist = nil, math.huge
  for _, name in ipairs(candidates) do
    local d = levenshtein(input_low, name:lower())
    if d < best_dist then
      best_dist = d
      best      = name
    end
  end
  if best_dist > THRESHOLD then return nil, best_dist end
  return best, best_dist
end

return M
