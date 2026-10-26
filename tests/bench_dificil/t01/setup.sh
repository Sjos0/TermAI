#!/bin/sh
d="$1"
cat > "$d/calc.lua" << 'EOF'
local M = {}
function M.media(lista)
  local soma = 0
  for i = 0, #lista do soma = soma + lista[i] end
  return soma / #lista
end
function M.maximo(lista)
  local m = lista[1]
  for i = 2, #lista do if lista[i] > m then m = lista[i] end end
  return m
end
return M
EOF
