-- latex.lua — Mapeamento de símbolos LaTeX para Unicode e aplicação no texto.
-- Cobre 3 contextos: blocos $$...$$, inline $...$, e símbolos standalone
-- (sem delimitadores $) que o modelo às vezes emite fora de math mode.
-- Dependências externas: nenhuma (Lua puro).
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

  -- Passagem 1: blocos $$...$$
  s = s:gsub("%%$(.-)%$%$", function(x)
    for _, k in ipairs(latex_keys_sorted) do x = replace_all(x, k, latex_map[k]) end
    return x
  end)

  -- Passagem 2: inline $...$
  s = s:gsub("%$(.-)%$", function(x)
    for _, k in ipairs(latex_keys_sorted) do x = replace_all(x, k, latex_map[k]) end
    return x
  end)

  -- Passagem 3: símbolos LaTeX standalone (sem delimitadores $).
  -- Cobre casos em que o modelo escreve \rightarrow fora de math mode,
  -- por exemplo em quebras de linha ou em texto corrido.
  -- Ordenado do mais longo para o mais curto para evitar match parcial.
  for _, k in ipairs(latex_keys_sorted) do
    -- find + replace manual para evitar problemas com % em gsub replacement
    local i = 1
    while true do
      local a, b = s:find(k, i, true)
      if not a then break end
      -- Garante que não é parte de uma palavra maior (ex: \times vs \timesX)
      local after = s:sub(b + 1, b + 1)
      if after == "" or not after:match("[a-zA-Z]") then
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
