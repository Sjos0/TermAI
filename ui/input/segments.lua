-- segments.lua — Mini-DSL para manipulação de input como lista de segmentos.
-- Segmento: { kind="text", val=string } | { kind="paste", val=string, idx=number }
-- Permite que texto digitado e texto colado coexistam e sejam removidos corretamente.
-- Dependências externas: nenhuma (Lua puro).
local M = {}

local function seg_get_input(segs)
  local parts = {}
  for _, s in ipairs(segs) do
    parts[#parts + 1] = s.val
  end
  return table.concat(parts)
end

local function count_lines(text)
  if not text or text == "" then return 0 end
  local count = 0
  for _ in (text .. "\n"):gmatch("([^\n]*)\n") do
    count = count + 1
  end
  return count
end

local function seg_get_display(segs)
  local parts = {}
  for _, s in ipairs(segs) do
    if s.kind == "paste" then
      local l_count = count_lines(s.val)
      parts[#parts + 1] = "\27[38;5;220m[pasted_text#" .. s.idx .. " + " .. l_count .. " linha(s)]\27[39m"
    else
      parts[#parts + 1] = s.val
    end
  end
  return table.concat(parts)
end

local function seg_append_char(segs, char)
  if #segs == 0 or segs[#segs].kind ~= "text" then
    segs[#segs + 1] = { kind = "text", val = char }
  else
    segs[#segs].val = segs[#segs].val .. char
  end
end

local function seg_backspace(segs)
  if #segs == 0 then return false end
  local last = segs[#segs]
  if last.kind == "paste" then
    table.remove(segs)
    return true
  else
    local s = last.val
    if #s == 0 then table.remove(segs); return false end
    local i = #s
    while i > 1 and (s:byte(i) & 0xC0) == 0x80 do
      i = i - 1
    end
    last.val = s:sub(1, i - 1)
    if last.val == "" then table.remove(segs) end
    return true
  end
end

M.get_input   = seg_get_input
M.get_display = seg_get_display
M.append_char = seg_append_char
M.backspace   = seg_backspace
return M
