local M = {}

function M.run(expression)
  local env = setmetatable({
    sqrt  = math.sqrt,  abs   = math.abs,
    floor = math.floor, ceil  = math.ceil,
    round = function(x) return math.floor(x + 0.5) end,
    sin   = math.sin,   cos   = math.cos,
    tan   = math.tan,   asin  = math.asin,
    acos  = math.acos,  atan  = math.atan,
    log   = math.log,   exp   = math.exp,
    max   = math.max,   min   = math.min,
    pi    = math.pi,    e     = math.exp(1),
  }, { __index = function() return nil end })

  local fn, err = load("return " .. expression, "calc", "t", env)
  if not fn then 
    return nil, "❌ Expressão inválida: " .. tostring(err):gsub("%[string .-%]:", "linha") 
  end
  
  local ok, result = pcall(fn)
  if not ok then 
    return nil, "❌ Erro no cálculo: " .. tostring(result) 
  end
  
  return result
end

return M