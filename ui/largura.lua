-- ui/largura.lua — Largura visual conservadora (nunca subestima colunas no terminal).
-- SGR/CSI não contam como coluna (#265): medir e cortar pelo texto visível.
local M = {}

function M.visivel(s)
  return (tostring(s or "")):gsub("\27%[[0-9;:?]*[A-Za-z]", "")
end

local function is_wide(cp)
  if cp >= 0x1100 and cp <= 0x115F then return true end
  if cp >= 0x2E80 and cp <= 0xA4CF then return true end
  if cp >= 0xAC00 and cp <= 0xD7A3 then return true end
  if cp >= 0xF900 and cp <= 0xFAFF then return true end
  if cp >= 0xFE10 and cp <= 0xFE6F then return true end
  if cp >= 0xFF01 and cp <= 0xFF60 then return true end
  if cp >= 0xFFE0 and cp <= 0xFFE6 then return true end
  if cp >= 0x1F000 and cp <= 0x1FAFF then return true end
  if cp >= 0x2600 and cp <= 0x27BF then return true end
  if cp >= 0x2300 and cp <= 0x23FF then return true end
  -- só emoji presentation em 2Bxx (não ⬤ U+2B24, que o terminal desenha em 1 col)
  if cp == 0x2B1B or cp == 0x2B1C or cp == 0x2B50 or cp == 0x2B55 then return true end
  return false
end

local function cp_width(cp, prev)
  if cp == 0xFE0F then
    if prev and not is_wide(prev) then return 1 end
    return 0
  end
  if cp == 0x09 then return 8 end
  if cp < 0x20 or (cp >= 0x7F and cp < 0xA0) then return 0 end
  if is_wide(cp) then return 2 end
  return 1
end

local function colunas_plain(s)
  local n, prev = 0, nil
  local ok = pcall(function()
    for _, cp in utf8.codes(s) do
      n = n + cp_width(cp, prev)
      prev = cp
    end
  end)
  if not ok then return #s end
  return n
end

function M.colunas(s)
  return colunas_plain(M.visivel(s))
end

--- Expande TAB em espaços até a próxima parada de 8 colunas (linha lógica).
--- Não interpreta SGR; só texto visível + TABs.
function M.expand_tabs(s)
  s = tostring(s or "")
  local out, col = {}, 0
  local i = 1
  while i <= #s do
    local c = s:sub(i, i)
    if c == "\27" then
      local seq = s:sub(i):match("^(\27%[[0-9;:?]*[A-Za-z])")
      if seq then out[#out+1]=seq; i=i+#seq
      else out[#out+1]=c; i=i+1 end
    elseif c == "\t" then
      local n = 8 - (col % 8)
      out[#out+1] = string.rep(" ", n)
      col = col + n
      i = i + 1
    else
      local ok, cp = pcall(utf8.codepoint, s, i)
      if ok and cp then
        local ch = utf8.char(cp)
        out[#out+1] = ch
        -- largura aproximada para avanço de coluna
        if cp >= 0x1100 and (cp <= 0x115F or (cp >= 0x2E80 and cp <= 0xA4CF) or (cp >= 0xAC00 and cp <= 0xD7A3)
          or (cp >= 0x1F000 and cp <= 0x1FAFF)) then
          col = col + 2
        else
          col = col + 1
        end
        i = i + #ch
      else out[#out+1]=c; col=col+1; i=i+1 end
    end
  end
  return table.concat(out)
end


function M.cortar(s, max)
  s = tostring(s or "")
  if max <= 0 then return "" end
  if M.colunas(s) <= max then return s end
  if max == 1 then return "…" end
  local budget = max - 1
  local used, out, i, prev = 0, {}, 1, nil
  local had_csi = s:find("\27[", 1, true) ~= nil
  while i <= #s do
    local csi = s:match("^\27%[[0-9;:?]*[A-Za-z]", i)
    if csi then
      out[#out + 1] = csi
      i = i + #csi
    else
      local p = utf8.offset(s, 2, i)
      local last = p and (p - 1) or #s
      local ch = s:sub(i, last)
      local cp = utf8.codepoint(ch)
      local w = cp_width(cp, prev)
      if used + w > budget then break end
      used = used + w
      out[#out + 1] = ch
      prev = cp
      i = last + 1
    end
  end
  out[#out + 1] = "…"
  if had_csi then out[#out + 1] = "\27[0m" end
  local result = table.concat(out)
  while M.colunas(result) > max and #out > 1 do
    if had_csi and out[#out] == "\27[0m" then table.remove(out) end
    if out[#out] == "…" then table.remove(out) end
    while #out > 0 and out[#out]:match("^\27%[") do table.remove(out) end
    if #out > 0 then table.remove(out) end
    out[#out + 1] = "…"
    if had_csi then out[#out + 1] = "\27[0m" end
    result = table.concat(out)
  end
  return result
end

return M
