-- ui/estilo/fundo.lua — reaplica fundo após cada reset SGR (função pura).
local M = {}

--- Reaplica `bg` imediatamente após cada `\27[0m` (ou SGR reset) dentro de `texto`.
--- Sem estado e sem I/O. Se `bg` for vazio, devolve `texto` inalterado.
function M.fundo_seguro(bg, texto)
  texto = tostring(texto or "")
  if not bg or bg == "" then return texto end
  -- após reset completo, reaplicar fundo
  local out = texto:gsub("\27%[0m", "\27[0m" .. bg)
  return out
end

return M
