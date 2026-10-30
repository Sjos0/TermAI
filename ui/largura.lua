-- ui/largura.lua — Largura visual conservadora (nunca subestima colunas no terminal).
-- Módulo puro: sem I/O. Emoji/CJK = 2; tab = 8; controle = 0; VS16 após base estreito = +1.
local M = {}

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

function M.colunas(s)
  s = tostring(s or "")
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

function M.cortar(s, max)
  s = tostring(s or "")
  if max <= 0 then return "" end
  if M.colunas(s) <= max then return s end
  if max == 1 then return "…" end
  local budget = max - 1
  local used, last_end, prev = 0, 0, nil
  local ok = pcall(function()
    for p, cp in utf8.codes(s) do
      local w = cp_width(cp, prev)
      if used + w > budget then return end
      used = used + w
      local nxt = utf8.offset(s, 2, p)
      last_end = nxt and (nxt - 1) or #s
      prev = cp
    end
  end)
  if not ok or last_end <= 0 then return "…" end
  local out = s:sub(1, last_end) .. "…"
  -- garantia: nunca ultrapassa max
  while M.colunas(out) > max and last_end > 0 do
    last_end = last_end - 1
    while last_end > 0 and s:byte(last_end + 1) and s:byte(last_end + 1) >= 0x80 and s:byte(last_end + 1) < 0xC0 do
      last_end = last_end - 1
    end
    out = s:sub(1, last_end) .. "…"
  end
  return out
end

return M
