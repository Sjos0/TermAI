-- ui/largura_wrap.lua — quebra texto por largura visual, sem depender de ui.largura.
-- O medidor é injetado pelo consumidor para evitar dependência circular.
local M = {}

local function proximo_segmento(texto, indice)
  local ansi = texto:sub(indice):match("^\27%[[0-9;:?]*[A-Za-z]")
  if ansi then return ansi, indice + #ansi, true end

  local ok, cp = pcall(utf8.codepoint, texto, indice)
  if ok and cp then
    local tamanho = cp <= 0x7F and 1 or cp <= 0x7FF and 2
      or cp <= 0xFFFF and 3 or 4
    local fim = math.min(#texto, indice + tamanho - 1)
    return texto:sub(indice, fim), fim + 1, false
  end

  -- Bytes UTF-8 inválidos são preservados individualmente; o medidor decide
  -- a largura conservadora (ui.largura usa #texto nesse caso).
  return texto:sub(indice, indice), indice + 1, false
end

local function quebrar_token(token, limite, colunas)
  local partes, atual = {}, ""
  local indice = 1
  while indice <= #token do
    local segmento, proximo, ansi = proximo_segmento(token, indice)
    local candidato = atual .. segmento
    if not ansi and atual ~= "" and colunas(candidato) > limite
        and colunas(atual) > 0 then
      partes[#partes + 1] = atual
      atual = segmento
    else
      atual = candidato
    end
    indice = proximo
  end
  if atual ~= "" then partes[#partes + 1] = atual end
  return partes
end

-- API única: quebrar(texto, limite, medir_colunas).
-- medir_colunas deve contar colunas visíveis, ignorando ANSI/SGR e tratando UTF-8.
function M.quebrar(texto, limite, medir_colunas)
  assert(type(medir_colunas) == "function",
    "ui.largura_wrap.quebrar requer a função medir_colunas")

  texto = tostring(texto or "")
  limite = math.max(1, math.floor(tonumber(limite) or 1))

  local linhas, atual = {}, ""
  for palavra in texto:gmatch("%S+") do
    local partes = quebrar_token(palavra, limite, medir_colunas)
    for _, parte in ipairs(partes) do
      if atual == "" then
        atual = parte
      elseif medir_colunas(atual .. " " .. parte) <= limite then
        atual = atual .. " " .. parte

      else
        linhas[#linhas + 1] = atual
        atual = parte
      end
    end
  end

  if atual ~= "" then linhas[#linhas + 1] = atual end
  if #linhas == 0 then linhas[1] = "" end
  return linhas
end

return M
