-- ui/estilo/fundo.lua — reaplica fundo só após SGR que mexem no fundo/reset (puro).
local M = {}

-- SGR que afetam fundo ou resetam: 0, vazio, 4x, 10x, 48;..., 49
local function afeta_fundo(params, letter)
  if letter == "K" or letter == "J" then return true end
  if letter ~= "m" then return false end
  if params == "" or params == "0" then return true end
  for p in (params .. ";"):gmatch("([^;]*);") do
    local n = tonumber(p)
    if n == 0 then return true end
    if n == 49 then return true end
    if n and n >= 40 and n <= 47 then return true end
    if n and n >= 100 and n <= 107 then return true end
  end
  if params:find("^48;") or params:find(";48;") then return true end
  return false
end

--- Após SGR de fundo/reset e após ESC[K]/J], reemite `bg`.
--- Códigos só de texto (30–37, 38;5, 1, 2, …) não disparam reemissão.
function M.fundo_seguro(bg, texto)
  texto = tostring(texto or "")
  if not bg or bg == "" then return texto end
  local out = {}
  local i, n = 1, #texto
  while i <= n do
    local c = texto:sub(i, i)
    if c == "\27" then
      local seq = texto:sub(i):match("^(\27%[[0-9;:?]*[mKJ])")
      if seq then
        out[#out + 1] = seq
        local params = seq:match("^\27%[([0-9;:?]*)") or ""
        local letter = seq:sub(-1)
        if afeta_fundo(params, letter) then out[#out + 1] = bg end
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
