-- agent/tools_handler/xml_extractor.lua
-- Funcoes puras de extracao XML usando find + sub. Sem dependencias externas.
local M = {}

local function extract_first(s, open_tag, close_tag)
  local start = s:find(open_tag, 1, true)
  if not start then return nil end
  start = start + #open_tag
  local close_pos = s:find(close_tag, start, true)
  if not close_pos then return nil end
  return s:sub(start, close_pos - 1):match("^%s*(.-)%s*$") or ""
end

local function extract_last(s, open_tag, close_tag)
  local start = s:find(open_tag, 1, true)
  if not start then return nil end
  start = start + #open_tag
  local last_end, pos = nil, start
  while true do
    local found = s:find(close_tag, pos, true)
    if not found then break end
    last_end = found
    pos = found + 1
  end
  if not last_end then return nil end
  return s:sub(start, last_end - 1):match("^%s*(.-)%s*$") or ""
end

local function find_top_level_blocks(text, open_tag, close_tag)
  local blocks = {}
  local i = 1
  while i <= #text do
    local s = text:find(open_tag, i, true)
    if not s then break end
    local depth = 1
    local j = s + #open_tag
    local found_close = nil
    while j <= #text do
      local o = text:find(open_tag,  j, true)
      local c = text:find(close_tag, j, true)
      if not c then depth = -1; break end
      if o and o < c then
        depth = depth + 1
        j = o + #open_tag
      else
        depth = depth - 1
        if depth == 0 then found_close = c; break end
        j = c + #close_tag
      end
    end
    if found_close then
      local e = found_close + #close_tag - 1
      blocks[#blocks+1] = {s = s, e = e}
      i = e + 1
    else
      break
    end
  end
  return blocks
end

M.extract_first         = extract_first
M.extract_last          = extract_last
M.find_top_level_blocks = find_top_level_blocks

return M
