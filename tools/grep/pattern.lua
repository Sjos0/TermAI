-- tools/grep/pattern.lua — Validação de Lua patterns (NÃO é regex).
-- Cobre as classes de erro que o Lua 5.4 levanta em lstrlib.c: '%' no fim, '[' sem ']',
-- parênteses desbalanceados, %b sem argumentos e %f sem '['. Sem isso o Grep devolve
-- "nenhum resultado" para um padrão inválido, e o agente conclui que o código não existe (issue #91).
local M = {}

-- Retorna nil se o padrão é válido; senão, a descrição curta do problema.
function M.validate(p)
  if type(p) ~= "string" or p == "" then return "padrão vazio" end
  -- Como o Lua: sem caracteres especiais ("^$*+?.([%-"), string.find faz busca literal e não erra.
  if not p:find("[%^%$%*%+%?%.%(%[%%%-]") then return nil end
  local i, n, depth = 1, #p, 0
  while i <= n do
    local c = p:sub(i, i)
    if c == "%" then
      if i == n then return "termina com '%' (use '%%' para um % literal)" end
      local e = p:sub(i + 1, i + 1)
      if e == "b" then
        if i + 3 > n then return "%b precisa de dois caracteres, ex.: %b()" end
        i = i + 4
      elseif e == "f" then
        if p:sub(i + 2, i + 2) ~= "[" then return "%f precisa ser seguido de '[', ex.: %f[%w]" end
        i = i + 2
      else
        i = i + 2
      end
    elseif c == "[" then
      local j = i + 1
      if p:sub(j, j) == "^" then j = j + 1 end
      if p:sub(j, j) == "]" then j = j + 1 end   -- ']' logo após '[' é literal
      local closed = false
      while j <= n do
        local d = p:sub(j, j)
        if d == "%" then j = j + 2
        elseif d == "]" then closed = true; break
        else j = j + 1 end
      end
      if not closed then return "conjunto '[' sem ']' correspondente" end
      i = j + 1
    elseif c == "(" then
      depth = depth + 1
      i = i + 1
    elseif c == ")" then
      depth = depth - 1
      if depth < 0 then return "')' sem '(' correspondente" end
      i = i + 1
    else
      i = i + 1
    end
  end
  if depth ~= 0 then return "'(' sem ')' correspondente" end
  return nil
end

-- True se há '|' fora de escape. Em Lua pattern é literal, não alternância.
function M.has_alternation(p)
  local i, n = 1, #p
  while i <= n do
    local c = p:sub(i, i)
    if c == "%" then i = i + 2
    elseif c == "|" then return true
    else i = i + 1 end
  end
  return false
end

return M
