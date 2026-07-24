local M = {}

local BAD = {['"']=1,["'"]=1,["$"]=1,["`"]=1,[";"]=1,["|"]=1,
             ["&"]=1,["("]=1,[")"]=1,["{"]=1,["}"]=1,["<"]=1,[">"]=1,
             ["\\"]=1,["!"]=1,["\n"]=1,["\r"]=1}

local function validate_chars(val, name)
  for i = 1, #val do
    if BAD[val:sub(i, i)] then
      print("[ERRO] " .. name .. " contém caractere inseguro na posição " .. i)
      os.exit(1)
    end
  end
end

function M.validate(endpoint, api_key)
  -- Endpoint é obrigatório
  if not endpoint or endpoint == "" then
    print("[ERRO] endpoint está vazio")
    os.exit(1)
  end
  validate_chars(endpoint, "endpoint")

  -- API Key é OPCIONAL (provedores sem autenticação deixam vazio)
  if api_key and api_key ~= "" then
    validate_chars(api_key, "api_key")
  end
end

return M
