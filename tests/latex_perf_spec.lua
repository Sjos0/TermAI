-- tests/latex_perf_spec.lua — Testes de unidade e benchmark para renderer.latex
local latex = require("renderer.latex")

print("=== 1. Testes de Corretude (renderer.latex) ===")

-- Textos sem backslash (fast-path)
local plain = "Texto simples sem qualquer LaTeX ou barra invertida."
assert(latex.apply_latex(plain) == plain, "Texto simples deve retornar inalterado")
assert(latex.apply_latex("") == "", "String vazia deve retornar string vazia")
assert(latex.apply_latex(nil) == "", "nil deve retornar string vazia")

-- Textos com símbolos LaTeX (path normal)
local with_latex = "Seja A \\to B e x \\times y."
local expected = "Seja A → B e x × y."
assert(latex.apply_latex(with_latex) == expected, "Símbolos LaTeX devem ser convertidos corretamente")

-- Bloco math mode $...$
local inline_math = "$x \\to y$"
assert(latex.apply_latex(inline_math) == "x → y", "Inline math deve converter símbolos dentro e remover delimitadores")

local inline_math_nobackslash = "$x = y$"
assert(latex.apply_latex(inline_math_nobackslash) == "x = y", "Inline math sem backslash deve processar delimitadores $")

print("✅ Todos os testes de corretude passaram!")

print("\n=== 2. Micro-benchmark de Performance ===")

local iterations = 100000
local text_plain = "Esta é uma linha típica de resposta da API sem símbolos LaTeX ou barras."

local t0 = os.clock()
for i = 1, iterations do
  latex.apply_latex(text_plain)
end
local elapsed = os.clock() - t0

print(string.format("Tempo para %d chamadas em texto simples: %.4f segundos", iterations, elapsed))
assert(elapsed < 0.5, "Desempenho em texto simples deve ser extremamente rápido (< 0.5s para 100k chamadas)")

print("\nRESULTADO: Todos os testes passaram com sucesso!")
