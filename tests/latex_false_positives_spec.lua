-- tests/latex_false_positives_spec.lua
-- Regressão Issue #36: apply_latex não deve mutar paths, moeda nem substrings.
-- Também garante que math mode legítimo e standalone intencional continuam ok.
--
-- "E se isso mudar?": qualquer regressão em left-boundary, heurística de moeda,
-- pattern $$...$$ ou stripping de math legítimo deve falhar aqui antes de
-- chegar à TUI. Origem: Issue #36 / PR #45.
--
-- Políticas travadas pós-review (Caçador):
-- - Inline: dígito inicial + sem \\ → preserva $...$ (moeda / math numérico)
-- - Display $$...$$: sem heurística de moeda (stripping normal)
-- - Standalone: left boundary [%w\\:] + right boundary letra
local latex = require("renderer.latex")

local pass, fail = 0, 0

local function check(name, input, expected)
  local ok, got = pcall(function()
    return latex.apply_latex(input)
  end)
  if not ok then
    fail = fail + 1
    print(string.format("  FAIL [%s] — exception: %s", name, tostring(got)))
    return
  end
  if got ~= expected then
    fail = fail + 1
    print(string.format(
      "  FAIL [%s]\n    input:    %q\n    expected: %q\n    got:      %q",
      name, input, expected, got
    ))
    return
  end
  pass = pass + 1
  print("  OK  " .. name)
end

print("=== Issue #36 — falsos positivos de substring / paths ===")

check("path Unix com \\to",
  "path\\to\\file", "path\\to\\file")

check("path Windows com \\times",
  "C:\\times\\data", "C:\\times\\data")

check("path com \\rightarrow",
  "dir\\rightarrow\\out", "dir\\rightarrow\\out")

check("path misto alfanumérico",
  "src\\alpha\\beta.lua", "src\\alpha\\beta.lua")

check("path com \\pi no meio",
  "docs\\pi\\chart.md", "docs\\pi\\chart.md")

print("\n=== Issue #36 — $ de moeda (pares fechados e abertos) ===")

-- Par fechado isolado: caminho canônico da heurística (lacuna apontada pelo Caçador)
check("par fechado $100$ preserva delimitadores",
  "$100$", "$100$")

check("moeda em frase com par fechado",
  "custa $100$ reais", "custa $100$ reais")

check("moeda isolada aberta $100",
  "price $100", "price $100")

check("duas moedas $100 e $200",
  "$100 and $200", "$100 and $200")

check("moeda com espaço $ 50",
  "custa $ 50", "custa $ 50")

check("moeda com espaço e par fechado $ 50$",
  "$ 50$", "$ 50$")

print("\n=== Política: math numérico sem backslash (pós-#36) ===")

-- Contrato consciente: dígito inicial + sem \\ → preserva $ (mesma heurística de moeda)
check("math numérico $2 + 2$ preserva delimitadores",
  "$2 + 2$", "$2 + 2$")

check("math numérico $3.14$ preserva",
  "$3.14$", "$3.14$")

-- Contraste: letra no início continua stripping (comportamento pré-existente)
check("math letra sem backslash $x = y$ continua stripping",
  "$x = y$", "x = y")

print("\n=== Assimetria display vs inline (documentada) ===")

-- Display NÃO tem heurística de moeda: $$100$$ vira 100
check("display $$100$$ faz stripping (sem heurística de moeda)",
  "$$100$$", "100")

check("display com comando $$\\alpha$$",
  "$$\\alpha$$", "α")

print("\n=== Guard de letra (direita) — comportamento intencional ===")

check("\\timesX não é comando isolado",
  "\\timesX", "\\timesX")

check("standalone intencional a \\times b",
  "a \\times b", "a × b")

check("standalone no início",
  "\\to destino", "→ destino")

check("standalone após pontuação",
  "(ver \\alpha)", "(ver α)")

-- Left boundary também após dígito (conservador)
check("standalone após dígito 2\\to3 preserva",
  "2\\to3", "2\\to3")

print("\n=== Math mode legítimo continua funcionando ===")

check("inline $x \\to y$",
  "$x \\to y$", "x → y")

check("inline com comando e dígito $x \\times 2$",
  "$x \\times 2$", "x × 2")

check("display $$\\alpha + \\beta$$",
  "$$\\alpha + \\beta$$", "α + β")

check("texto + standalone misto",
  "Seja A \\to B e x \\times y.", "Seja A → B e x × y.")

check("path + standalone intencional na mesma string",
  "ver path\\to\\file e depois A \\to B",
  "ver path\\to\\file e depois A → B")

print("\n=== Casos de borda ===")

check("nil → string vazia", nil, "")
check("string vazia", "", "")
check("texto plano sem \\ ou $",
  "Texto simples sem LaTeX.", "Texto simples sem LaTeX.")

check("apenas $", "$", "$")
check("$$ vazio", "$$$$", "")

print(string.format(
  "\n══ RESULTADO: %d passaram, %d falharam (total: %d) ══",
  pass, fail, pass + fail))

if fail > 0 then
  print("⚠️  FALHA DETECTADA")
  os.exit(1)
else
  print("✅ Todos os testes de regressão #36 passaram!")
end
