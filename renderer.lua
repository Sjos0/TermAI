local M = {}

local ESC = "\27["

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

local function apply_latex(s)
  -- helper: substitui 'old' por 'new' (literal, sem patterns)
  local function replace_all(text, old, new)
    local result = text
    while true do
      local i, j = result:find(old, 1, true)  -- plain=true
      if not i then break end
      result = result:sub(1, i-1) .. new .. result:sub(j+1)
    end
    return result
  end

  -- substitui dentro de $$...$$
  s = s:gsub("%$%$(.-)%$%$", function(x)
    for k, v in pairs(latex_map) do
      x = replace_all(x, k, v)
    end
    return x
  end)

  -- substitui dentro de $...$
  s = s:gsub("%$(.-)%$", function(x)
    for k, v in pairs(latex_map) do
      x = replace_all(x, k, v)
    end
    return x
  end)

  -- substitui globalmente (fora de $ também)
  for k, v in pairs(latex_map) do
    s = replace_all(s, k, v)
  end

  return s
end


local function render_line(s)
  -- títulos
  if s:match("^#### ") then
    return ESC.."1m"..ESC.."38;5;220m▸ "..s:sub(6)..ESC.."0m"
  elseif s:match("^### ") then
    return ESC.."1m"..ESC.."38;5;80m▸▸ "..s:sub(5)..ESC.."0m"
  elseif s:match("^## ") then
    return ESC.."1m"..ESC.."38;5;39m▸▸▸ "..s:sub(4)..ESC.."0m"
  elseif s:match("^# ") then
    return ESC.."1m"..ESC.."38;5;255m"..s:sub(3)..ESC.."0m"
  end
  -- linha horizontal
  if s:match("^%-%-%-+$") or s:match("^%*%*%*+$") then
    return ESC.."38;5;238m"..string.rep("─",40)..ESC.."0m"
  end
  -- listas
  s = s:gsub("^%s*[%-%*•] (.+)$", "  "..ESC.."38;5;245m•"..ESC.."0m %1")
  s = s:gsub("^%s*(%d+)%. (.+)$", function(n,r)
    return "  "..ESC.."38;5;245m"..n.."."..ESC.."0m "..r
  end)
  -- citação
  s = s:gsub("^> (.+)$", ESC.."38;5;245m│ "..ESC.."3m%1"..ESC.."0m")
  -- inline: código, negrito+itálico, negrito, itálico, sublinhado
  s = s:gsub("`([^`]+)`",       ESC.."38;5;220m%1"..ESC.."0m")
  s = s:gsub("%*%*%*(.-)%*%*%*", ESC.."1m"..ESC.."3m%1"..ESC.."0m")
  s = s:gsub("%*%*(.-)%*%*",    ESC.."1m%1"..ESC.."22m")
  s = s:gsub("%*(.-)%*",        ESC.."3m%1"..ESC.."23m")
  s = s:gsub("__(.-)__",        ESC.."4m%1"..ESC.."24m")
  return s
end

-- renderiza string com múltiplas linhas corretamente
function M.render(s)
  s = s or ""
  s = apply_latex(s)
  local out = {}
  for line in (s.."\n"):gmatch("([^\n]*)\n") do
    out[#out+1] = render_line(line)
  end
  -- remove último \n extra que gmatch adiciona
  local result = table.concat(out, "\n")
  if result:sub(-1)=="\n" then result=result:sub(1,-2) end
  return result
end

return M
