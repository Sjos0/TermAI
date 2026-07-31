-- tools/error_feedback/fuzzy_match.lua
-- Levenshtein simplificado para sugerir nomes de ferramentas proximos.
-- Otimizado (Bolt): Cache de caracteres, poda de tamanho e caminhos de correspondência exata rápidos.
local M = {}

local function levenshtein(char_a, la, b)
  local lb = #b
  if la == 0 then return lb end
  if lb == 0 then return la end

  -- Cache dos caracteres da string b para evitar chamadas lentas a sub no loop interno
  local char_b = {}
  for j = 1, lb do char_b[j] = b:sub(j, j) end

  local row = {}
  for j = 0, lb do row[j] = j end
  for i = 1, la do
    local prev = i
    local ai = char_a[i]
    for j = 1, lb do
      local cost = (ai == char_b[j]) and 0 or 1
      -- Inlining de math.min para evitar sobrecarga de chamadas de função adicionais
      local v1 = row[j] + 1
      local v2 = prev + 1
      local v3 = row[j-1] + cost
      local val = v1 < v2 and (v1 < v3 and v1 or v3) or (v2 < v3 and v2 or v3)
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

  -- 1. Otimização de caminho exato rápido (Case-sensitive)
  for _, name in ipairs(candidates) do
    if input == name then
      return name, 0
    end
  end

  local THRESHOLD = 5
  local input_low = input:lower()
  local la = #input_low

  -- Lazy initialization do cache de caracteres de input_low.
  -- Será construído uma única vez, apenas se ao menos um candidato
  -- passar na poda de comprimento e requerer cálculo de Levenshtein.
  local char_a = nil

  local best, best_dist = nil, math.huge

  -- 2 e 3. Unificação de loops case-insensitive e Levenshtein com name:lower() único.
  for _, name in ipairs(candidates) do
    local name_low = name:lower()

    -- Se for igual case-insensitive, é um match perfeito (distância 0)
    if input_low == name_low then
      return name, 0
    end

    -- Otimização de poda por comprimento: se a diferença de comprimento absoluto
    -- for maior ou igual a THRESHOLD ou maior ou igual à melhor distância já encontrada,
    -- podemos ignorar com segurança esse candidato sem executar o cálculo de Levenshtein.
    local len_diff = math.abs(la - #name_low)
    if len_diff < best_dist and len_diff <= THRESHOLD then
      if not char_a then
        char_a = {}
        for i = 1, la do char_a[i] = input_low:sub(i, i) end
      end

      local d = levenshtein(char_a, la, name_low)
      if d < best_dist then
        best_dist = d
        best      = name
      end
    end
  end

  if best_dist > THRESHOLD then return nil, best_dist end
  return best, best_dist
end

return M
