local M = {}

function M.format(result, expression)
  if result == nil then 
    return "[FAIL] Resultado indefinido. Verifique a expressão." 
  end
  if type(result) ~= "number" then 
    return "[FAIL] Resultado inesperado: " .. tostring(result) 
  end
  if result ~= result then 
    return "[FAIL] Resultado inválido (NaN)." 
  end
  if result == math.huge or result == -math.huge then 
    return "[FAIL] Resultado infinito — possível divisão por zero." 
  end

  local formatted
  if math.floor(result) == result and math.abs(result) < 1e15 then
    formatted = tostring(math.floor(result))
  else
    formatted = string.format("%.10g", result)
  end

  return "[OK] " .. expression .. " = " .. formatted
end

return M