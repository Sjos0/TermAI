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
  if cp >= 0x2B00 and cp <= 0x2BFF then return true end
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

function M.cortar(s, max)
  s = tostring(s or "")
  if max <= 0 then return "" end
  if M.colunas(s) <= max then return s end
  if max == 1 then return "…" end
  local budget = max - 1
  local used = 0
  local out = {}
  local i = 1
  local prev = nil
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
  out[#out + 1] = "\27[0m"
  local result = table.concat(out)
  while M.colunas(result) > max and #out > 2 do
    table.remove(out, #out)
    table.remove(out, #out)
    while #out > 0 and out[#out]:match("^\27%[") do table.remove(out) end
    if #out > 0 then table.remove(out) end
    out[#out + 1] = "…"
    out[#out + 1] = "\27[0m"
    result = table.concat(out)
  end
  return result
end

return M
