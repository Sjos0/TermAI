-- terminal_read.lua — Leitura de sequências de escape ANSI e conteúdo de bracketed paste.
-- ⚠️ Usa io.read(1) diretamente em stdin raw. NÃO adicionar lógica extra, timeout
-- ou verificações que não existam no original — o terminal está em modo raw.
local M = {}

local function read_escape_seq()
  local b2 = io.read(1)
  if not b2 then return nil, nil end

  if b2 == "[" then
    local seq = ""
    while true do
      local b = io.read(1)
      if not b then break end
      seq = seq .. b
      if b:byte() >= 0x40 and b:byte() <= 0x7E then break end
    end
    return "csi", seq
  elseif b2 == "O" then
    io.read(1)
    return "ss3", nil
  else
    return "other", b2
  end
end

local function read_bracketed_paste()
  local parts = {}
  while true do
    local pb = io.read(1)
    if not pb then break end
    local pc = pb:byte()

    if pc == 27 then
      local kind, seq = read_escape_seq()
      if kind == "csi" and seq == "201~" then
        break
      else
        if kind == "csi" then
          parts[#parts + 1] = "\27[" .. (seq or "")
        elseif kind == "ss3" then
          parts[#parts + 1] = "\27O"
        else
          parts[#parts + 1] = "\27" .. (seq or "")
        end
      end
    else
      parts[#parts + 1] = pb
    end
  end

  local pasted = table.concat(parts)
  pasted = pasted:gsub("\r\n", "\n"):gsub("\r", "\n")
  pasted = pasted:match("^(.-)\n*$") or pasted
  return pasted
end

M.read_escape_seq      = read_escape_seq
M.read_bracketed_paste = read_bracketed_paste
return M
