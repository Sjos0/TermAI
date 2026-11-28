-- ui/largura_wrap.lua — quebra visual sem perder caracteres ou palavras longas.
local largura = require("ui.largura")
local M = {}

local function quebrar_token(token, limite)
  local caracteres = {}
  local valido = pcall(function()
    for _, cp in utf8.codes(token) do
      caracteres[#caracteres + 1] = utf8.char(cp)
    end
  end)
  if not valido then
    for i = 1, #token do caracteres[#caracteres + 1] = token:sub(i, i) end
  end
  local linhas, atual = {}, ""
  for _, caractere in ipairs(caracteres) do
    if atual ~= "" and largura.colunas(atual .. caractere) > limite then
      linhas[#linhas + 1] = atual
      atual = caractere
    else
      atual = atual .. caractere
    end
  end
  if atual ~= "" then linhas[#linhas + 1] = atual end
  return linhas
end

-- Quebra palavras e tokens longos sem truncar conteúdo.
function M.quebrar(texto, limite)
  limite = math.max(1, math.floor(tonumber(limite) or 1))
  local linhas, atual = {}, ""
  for palavra in (tostring(texto or "") .. " "):gmatch("(%S+)%s*") do
    local candidata = atual == "" and palavra or atual .. " " .. palavra
    if largura.colunas(candidata) <= limite then
      atual = candidata
    else
      if atual ~= "" then linhas[#linhas + 1] = atual end
      if largura.colunas(palavra) <= limite then
        atual = palavra
      else
        local partes = quebrar_token(palavra, limite)
        for i = 1, #partes - 1 do linhas[#linhas + 1] = partes[i] end
        atual = partes[#partes] or ""
      end
    end
  end
  if atual ~= "" then linhas[#linhas + 1] = atual end
  if #linhas == 0 then linhas[1] = "" end
  return linhas
end

return M
