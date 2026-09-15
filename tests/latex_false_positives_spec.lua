-- tests/latex_false_positives_spec.lua
-- Regressão Issue #36: apply_latex não deve mutar paths, moeda nem substrings.
-- Também garante que math mode legítimo e standalone intencional continuam ok.
local latex = require("renderer.latex")

local function check(name, input, expected)
  local got = latex.apply_latex(input)
  if got ~= expected then
    error(string.format(
      "FAIL [%s]\n  input:    %q\n  expected: %q\n  got:      %q",
      name, input, expected, got
    ), 2)
  end
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

print("\n=== Issue #36 — $ de moeda / desbalanceados ===")

check("moeda isolada $100",
  "price $100", "price $100")

check("duas moedas $100 e $200",
  "$100 and $200", "$100 and $200")

check("moeda com espaço $ 50",
  "custa $ 50", "custa $ 50")

print("\n=== Guard de letra (direita) — comportamento intencional ===")

check("\\timesX não é comando isolado",
  "\\timesX", "\\timesX")

check("standalone intencional a \\times b",
  "a \\times b", "a × b")

check("standalone no início",
  "\\to destino", "→ destino")

check("standalone após pontuação",
  "(ver \\alpha)", "(ver α)")

print("\n=== Math mode legítimo continua funcionando ===")

check("inline $x \\to y$",
  "$x \\to y$", "x → y")

check("inline sem backslash $x = y$",
  "$x = y$", "x = y")

check("display $$\\alpha + \\beta$$",
  "$$\\alpha + \\beta$$", "α + β")

check("texto + standalone misto",
  "Seja A \\to B e x \\times y.", "Seja A → B e x × y.")

print("\n=== Casos de borda ===")

check("nil → string vazia", nil, "")
check("string vazia", "", "")
check("texto plano sem \\ ou $",
  "Texto simples sem LaTeX.", "Texto simples sem LaTeX.")

print("\n✅ Todos os testes de regressão #36 passaram!")
