return function(colunas)
local function dividir_palavra(palavra, max)
  local partes, atual, col, i = {}, "", 0, 1
  while i <= #palavra do
    local seq = palavra:sub(i):match("^\27%[[0-9;:?]*[A-Za-z]")
    if seq then atual, i = atual .. seq, i + #seq
    else
      local proximo = utf8.offset(palavra, 2, i)
      local fim = proximo and proximo - 1 or #palavra
      local ch = palavra:sub(i, fim)
      local peso = colunas(ch)
      if col + peso > max and atual ~= "" then
        partes[#partes + 1], atual, col = atual, "", 0
      end
      atual, col, i = atual .. ch, col + peso, fim + 1
    end
  end
  if atual ~= "" then partes[#partes + 1] = atual end
  return partes
end

  return function(s, max)
  s, max = tostring(s or ""), math.max(1, math.floor(tonumber(max) or 1))
  local linhas, atual, col = {}, "", 0
  for palavra in s:gmatch("%S+") do
    for _, parte in ipairs(dividir_palavra(palavra, max)) do
      local peso = colunas(parte)
      if atual == "" then atual, col = parte, peso
      elseif col + 1 + peso <= max then atual, col = atual .. " " .. parte, col + 1 + peso
      else linhas[#linhas + 1], atual, col = atual, parte, peso end
    end
  end
  if atual ~= "" then linhas[#linhas + 1] = atual end
  return linhas
end
end
