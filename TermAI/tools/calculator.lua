-- tools/calculator.lua — Ferramenta "calcular".
-- v2: schema JSON para native tool calling + arg backward compat.
local M = {}

function M.register(tools)
  local validator = require("tools.calculator.validator")
  local engine    = require("tools.calculator.engine")
  local formatter = require("tools.calculator.formatter")

  tools.register("calcular",
    "OBRIGATÓRIO para qualquer cálculo numérico antes de responder. "
    .. "Nunca calcule mentalmente. "
    .. "ATENÇÃO: % em Lua = módulo. Para porcentagens use frações: 15% → (15/100)*200. "
    .. "Arg: expressão matemática válida em Lua.",
    function(arg)
      local expr = type(arg) == "table" and (arg.expression or arg.arg or "") or arg
      local clean_arg, err = validator.check(expr)
      if not clean_arg then return err end
      local result, calc_err = engine.run(clean_arg)
      if not result and calc_err then return calc_err end
      return formatter.format(result, clean_arg)
    end,
    {
      type = "object",
      properties = {
        expression = {
          type = "string",
          description = "Expressão matemática em Lua. Ex: '5+3*2', 'sqrt(16)', '(15/100)*200'. Use (15/100) para porcentagens — % é módulo em Lua."
        }
      },
      required = {"expression"}
    }
  )
end

return M
