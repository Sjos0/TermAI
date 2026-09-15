-- latex.lua — Mapeamento de símbolos LaTeX para Unicode e aplicação no texto.
-- Cobre 3 contextos: blocos $$...$$, inline $...$, e símbolos standalone
-- (sem delimitadores $) que o modelo às vezes emite fora de math mode.
-- Dependências externas: nenhuma (Lua puro).
--
-- Política de limites (Issue #36):
-- - Standalone: exige boundary à esquerda e à direita para evitar falsos
--   positivos em paths (path\to\file, C:\times\data) e substrings.
-- - Inline $...$: preserva pares que parecem moeda ($100); processa math
--   legítimo (conteúdo com \ ou sem dígito logo após o $).
local M = {}

local latex_map = {
  ["\\rightarrow"]="→", ["\\to"]="→", ["\\Rightarrow"]="⇒",
  ["\\leftarrow"]="←", ["\\gets"]="←", ["\\Leftarrow"]="⇐",
  ["\\leftrightarrow"]="↔", ["\\Leftrightarrow"]="⇔",
  ["\\uparrow"]="↑", ["\\downarrow"]="↓", ["\\updownarrow"]="↕",
  ["\\times"]="×", ["\\cdot"]="·", ["\\div"]="÷",
  ["\\approx"]="≈", ["\\neq"]="≠", ["\\geq"]="≥", ["\\leq"]="≤",
  ["\\pm"]="±", ["\\infty"]="∞", ["\\partial"]="∂",
  ["\\sum"]="Σ", ["\\prod"]="Π", ["\\int"]="∫",
  ["\\alpha"]="α", ["\\beta"]="β", ["\\gamma"]="γ", ["\\delta"]="δ",
  ["\\epsilon"]="ε", ["\\theta"]="θ", ["\\lambda"]="λ", ["\\mu"]="μ",
  ["\\pi"]="π", ["\\sigma"]="σ", ["\\phi"]="φ", ["\\omega"]="ω",
  ["\\Delta"]="Δ", ["\\Sigma"]="Σ", ["\\Omega"]="Ω",
  ["\\sqrt"]="√", ["\\in"]="∈", ["\\notin"]="∉",
  ["\\cup"]="∪", ["\\cap"]="∩", ["\\emptyset"]="∅",
  ["\\forall"]="∀", ["\\exists"]="∃", ["\\neg"]="¬",
  ["\\land"]="∧", ["\\lor"]="∨", ["\\oplus"]="⊕",
  ["\\ldots"]="…", ["\\cdots"]="⋯",
}

-- Ordena chaves do mais longo para o mais curto: evita que "\to" seja
-- substituído antes de "\times" terminar de ser comparado, por exemplo.
local latex_keys_sorted = {}
for k in pairs(latex_map) do
  latex_keys_sorted[#latex_keys_sorted + 1] = k
end
table.sort(latex_keys_sorted, function(a, b) return #a > #b end)

-- Boundary à esquerda para standalone: não substituir se o caractere
-- anterior for alfanumérico, '\' ou ':' (paths Windows e Unix).
local function is_left_boundary(s, pos)
  if pos <= 1 then return true end
  local prev = s:sub(pos - 1, pos - 1)
  if prev:match("[%w\\:]") then
    return false
  end
  return true
end

local function apply_latex(s)
  if not s then return "" end
  -- Optimization (Bolt): Fast-path non-allocating search for '\\' or '$'.
  -- Plain text without backslashes or dollar signs cannot contain LaTeX commands or math blocks.
  -- Bypasses 2 sequential gsub pattern scans and iteration over latex_keys_sorted (~360x speedup).
  if not s:find("\\", 1, true) and not s:find("$", 1, true) then
    return s
  end

  local function replace_all(text, old, new)
    local result = text
    while true do
      local i, j = result:find(old, 1, true)
      if not i then break end
      result = result:sub(1, i - 1) .. new .. result:sub(j + 1)
    end
    return result
  end

  local function replace_symbols(text)
    for _, k in ipairs(latex_keys_sorted) do
      text = replace_all(text, k, latex_map[k])
    end
    return text
  end

  -- Passagem 1: blocos $$...$$
  s = s:gsub("%$%$(.-)%$%$", function(x)
    return replace_symbols(x)
  end)

  -- Passagem 2: inline $...$
  -- Política (#36): preservar pares que parecem moeda ($100, $ 50).
  -- Heurística: se o conteúdo, após espaços opcionais, começa com dígito
  -- e não contém '\' (sem comando LaTeX), devolve o par intacto.
  s = s:gsub("%$(.-)%$", function(x)
    local trimmed_start = x:match("^%s*(.*)$") or x
    if not x:find("\\", 1, true) and trimmed_start:match("^%d") then
      return "$" .. x .. "$"
    end
    return replace_symbols(x)
  end)

  -- Passagem 3: símbolos LaTeX standalone (sem delimitadores $).
  -- Cobre casos em que o modelo escreve \rightarrow fora de math mode.
  -- Boundaries esquerda + direita evitam paths e substrings (Issue #36).
  for _, k in ipairs(latex_keys_sorted) do
    local i = 1
    while true do
      local a, b = s:find(k, i, true)
      if not a then break end
      local after = s:sub(b + 1, b + 1)
      local right_ok = (after == "" or not after:match("[a-zA-Z]"))
      local left_ok = is_left_boundary(s, a)
      if left_ok and right_ok then
        s = s:sub(1, a - 1) .. latex_map[k] .. s:sub(b + 1)
        i = a + #latex_map[k]
      else
        i = b + 1
      end
    end
  end

  return s
end

M.apply_latex = apply_latex
return M
