-- tools/calculator.lua — Ferramenta "calculate".
-- v2: schema JSON para native tool calling + arg backward compat.
local M = {}

function M.register(tools)
  local validator = require("tools.calculator.validator")
  local engine    = require("tools.calculator.engine")
  local formatter = require("tools.calculator.formatter")

  tools.register("calculate",
    [==[Evaluate a numeric expression written in Lua syntax and return the result. Use it for every arithmetic question, percentage and unit conversion; never calculate in your head. '%' is the Lua modulo operator, so write percentages as fractions, for example (15/100)*200. Pass one expression per call, for example '5+3*2', 'sqrt(16)' or '(15/100)*200'. Do not use it for dates, text or anything that is not a number expression.]==],
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
          description = "Expression in Lua syntax, for example '5+3*2', 'sqrt(16)' or '(15/100)*200'. Write percentages as fractions, because % is the Lua modulo operator."
        }
      },
      required = {"expression"}
    }
  )
end

return M
