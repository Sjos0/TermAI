-- ui/widgets/block/wrap.lua — quebra por palavra conservando caracteres.
local largura = require("ui.largura")
local M = {}

local function prefixo_que_cabe(word, max_w)
  if max_w <= 0 or word == "" then return "", word end
  if largura.colunas(word) <= max_w then return word, "" end
  local used, i, last_ok = 0, 1, 0
  while i <= #word do
    local p = utf8.offset(word, 2, i)
    local last = p and (p - 1) or #word
    local ch = word:sub(i, last)
    local w = largura.colunas(ch)
    if used + w > max_w then break end
    used = used + w
    last_ok = last
    i = last + 1
  end
  if last_ok == 0 then
    local p = utf8.offset(word, 2, 1) or (#word + 1)
    return word:sub(1, p - 1), word:sub(p)
  end
  return word:sub(1, last_ok), word:sub(last_ok + 1)
end

function M.wrap_text(text, max_w)
  if max_w <= 0 then return {} end
  text = tostring(text or "")
  local lines = {}
  local function push(chunk)
    if chunk == "" and #lines > 0 then return end
    lines[#lines + 1] = chunk
  end
  for paragraph in (text .. "\n"):gmatch("([^\n]*)\n") do
    if paragraph == "" then push("")
    else
      local cur = ""
      for word in paragraph:gmatch("%S+%s*") do
        local candidate = cur .. word
        if largura.colunas(candidate) <= max_w then cur = candidate
        else
          if cur ~= "" then push(cur:gsub("%s+$", "")) end
          while largura.colunas(word) > max_w do
            local piece, rest = prefixo_que_cabe(word, max_w)
            push(piece)
            word = rest
          end
          cur = word
        end
      end
      if cur ~= "" then push(cur:gsub("%s+$", "")) end
    end
  end
  if #lines == 0 then lines[1] = "" end
  return lines
end

return M
