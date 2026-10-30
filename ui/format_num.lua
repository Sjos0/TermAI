-- ui/format_num.lua — formato compacto de limites (#251).
local M = {}

--- Múltiplos exatos de 1e6 (>=1e6) → Xm / X.Ym; de 1000 → Xk; senão inteiro.
function M.formatar_limite(n)
  n = tonumber(n) or 0
  if n >= 1000000 and n % 1000000 == 0 then
    local m = n / 1000000
    if m == math.floor(m) then
      return tostring(math.floor(m)) .. "m"
    end
  end
  if n >= 1000000 and n % 100000 == 0 then
    local m = n / 1000000
    local s = string.format("%.1f", m)
    s = s:gsub("%.0$", "")
    return s .. "m"
  end
  if n >= 1000 and n % 1000 == 0 then
    return tostring(math.floor(n / 1000)) .. "k"
  end
  return tostring(math.floor(n))
end

return M
