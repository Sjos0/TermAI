-- tests/latex_false_positives_spec/02_n_casos_de_borda.lua — parte de latex_false_positives_spec.lua (ver fachada).
local harness = require("tests.helpers.harness")

local M = {}

function M.run()
  local latex = require("renderer.latex")


  local function check(name, input, expected)
    local ok, got = pcall(function()
      return latex.apply_latex(input)
    end)
    if not ok then
      harness.fail = harness.fail + 1
      print(string.format("  FAIL [%s] — exception: %s", name, tostring(got)))
      return
    end
    if got ~= expected then
      harness.fail = harness.fail + 1
      print(string.format(
        "  FAIL [%s]\n    input:    %q\n    expected: %q\n    got:      %q",
        name, input, expected, got
      ))
      return
    end
    harness.pass = harness.pass + 1
    print("  OK  " .. name)
  end


  print("\n=== Casos de borda ===")

  check("nil → string vazia", nil, "")
  check("string vazia", "", "")
  check("texto plano sem \\ ou $",
    "Texto simples sem LaTeX.", "Texto simples sem LaTeX.")

  check("apenas $", "$", "$")
  check("$$ vazio", "$$$$", "")

end

return M
