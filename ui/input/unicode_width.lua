-- unicode_width.lua — Cálculo de largura visual de strings Unicode para terminais.
-- Detecta caracteres CJK de largura dupla via faixas de codepoint.
-- Dependências externas: nenhuma (Lua puro, byte a byte).
local M = {}

local function display_width(s)
  local w = 0
  local i = 1
  local len = #s
  while i <= len do
    local b = s:byte(i)
    if b < 0x80 then
      w = w + 1; i = i + 1
    elseif b < 0xC0 then
      i = i + 1
    elseif b < 0xE0 then
      w = w + 1; i = i + 2
    elseif b < 0xF0 then
      local b2 = s:byte(i + 1) or 0
      local b3 = s:byte(i + 2) or 0
      local cp = ((b  & 0x0F) * 4096)
               + ((b2 & 0x3F) * 64)
               +  (b3 & 0x3F)
      if  (cp >= 0x1100 and cp <= 0x115F)
       or (cp >= 0x2E80 and cp <= 0x303E)
       or (cp >= 0x3040 and cp <= 0x33FF)
       or (cp >= 0x3400 and cp <= 0x9FFF)
       or (cp >= 0xAC00 and cp <= 0xD7AF)
       or (cp >= 0xF900 and cp <= 0xFAFF)
       or (cp >= 0xFE10 and cp <= 0xFE6F)
       or (cp >= 0xFF00 and cp <= 0xFF60)
       or (cp >= 0xFFE0 and cp <= 0xFFE6)
      then
        w = w + 2
      else
        w = w + 1
      end
      i = i + 3
    else
      w = w + 2; i = i + 4
    end
  end
  return w
end

M.display_width = display_width
return M
