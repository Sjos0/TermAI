local M = {}

function M.check(arg)
  arg = arg:match("^%s*(.-)%s*$")
  if arg == "" then return nil, "❌ Nenhuma expressão fornecida." end
  
  local test = arg:gsub("%s+", "")
  if test:match("[^%d%.%+%-%*/%%%(%)%^,a-zA-Z_]") then
    return nil, "❌ Expressão contém caracteres inválidos."
  end
  
  return arg
end

return M