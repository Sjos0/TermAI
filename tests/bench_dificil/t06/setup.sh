#!/bin/sh
d="$1"
mkdir -p "$d/lib"
cat > "$d/lib/texto.lua" << 'EOF'
local M = {}
-- Divide s pelo separador sep, preservando campos vazios.
function M.dividir(s, sep)
  local out = {}
  local inicio = 1
  while true do
    local pos = string.find(s, sep, inicio, true)
    if not pos then out[#out+1] = string.sub(s, inicio); break end
    out[#out+1] = string.sub(s, inicio, pos)
    inicio = pos + #sep
  end
  return out
end
-- Retorna os itens da página p (a primeira página é 1), com n itens por página.
function M.pagina(lista, p, n)
  local ini = (p - 1) * n
  local res = {}
  for i = ini, ini + n - 1 do
    if lista[i] ~= nil then res[#res+1] = lista[i] end
  end
  return res
end
return M
EOF
