-- error_classifier.lua — Classificação de erros de API e rede em linguagem humana.
local json = require("json")
local M = {}

local function classify_error(line, rcfg)
  if not line or line == "" then return "Sem resposta do servidor" end
  if line:match("Operation too slow") or line:match("speed limit") then
    return "Inatividade (" .. rcfg.idle_timeout .. "s sem receber dados)"
  end
  if line:match("timed out") or line:match("timeout") then
    return "Tempo Esgotado (" .. rcfg.timeout .. "s no total)"
  end
  if line:match("Could not resolve") or line:match("resolve host") then
    return "Servidor inacessível"
  end
  if line:match("Connection refused") then return "Conexão recusada" end
  local ok, data = pcall(json.decode, line)
  if ok and data then
    if data.error then
      local e = data.error
      if type(e) == "table" then return e.message or e.type or "API error" end
      return tostring(e)
    elseif data.errors and data.errors[1] and data.errors[1].message then
      local m = data.errors[1].message
      if m:match("used up your daily free") then
        return "Cota diária gratuita esgotada"
      end
      return m
    end
  end
  if line:match("curl:") then
    return line:gsub("^curl: %(%d+%) ", ""):gsub("%s+$", "")
  end
  return #line <= 80 and line or line:sub(1, 77) .. "..."
end

M.classify_error = classify_error
return M
