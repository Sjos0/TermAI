local M = {}

local BAD = {['"']=1,["'"]=1,["$"]=1,["`"]=1,[";"]=1,["|"]=1,
             ["&"]=1,["("]=1,[")"]=1,["{"]=1,["}"]=1,["<"]=1,[">"]=1,
             ["\\"]=1,["!"]=1,["\n"]=1,["\r"]=1}

function M.is_safe(val)
  if not val then return true end
  for i = 1, #val do
    local char = val:sub(i, i)
    if BAD[char] then
      return false, char
    end
  end
  return true
end

function M.validate_chars(val, name)
  local safe, char = M.is_safe(val)
  if not safe then
    print("[ERRO] " .. name .. " contém caractere inseguro: '" .. char .. "'")
    os.exit(1)
  end
end

return M
