-- ui/estilo/fundo.lua — reaplica fundo do card após qualquer SGR/erase (puro).
local M = {}

--- Após cada SGR (`ESC[...m`) e após `ESC[K]` / `ESC[J]`, reemite `bg`.
--- Não remove cores de texto; só garante o fundo do card.
--- Sem estado e sem I/O. Se `bg` for vazio, devolve `texto` inalterado.
function M.fundo_seguro(bg, texto)
  texto = tostring(texto or "")
  if not bg or bg == "" then return texto end
  local out = {}
  local i = 1
  local n = #texto
  while i <= n do
    local c = texto:sub(i, i)
    if c == "\27" then
      local seq = texto:sub(i):match("^(\27%[[0-9;:?]*[mKJ])")
      if seq then
        out[#out + 1] = seq
        out[#out + 1] = bg
        i = i + #seq
      else
        out[#out + 1] = c
        i = i + 1
      end
    else
      out[#out + 1] = c
      i = i + 1
    end
  end
  return table.concat(out)
end

return M
