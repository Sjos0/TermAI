-- ui/cell/buffer.lua — buffer de células com fundo fixo (puro).
local estilo = require("ui.cell.estilo")
local M = {}

function M.new(tw, bg_code)
  return {
    tw = tw or 80,
    bg = bg_code or 234,
    cells = {},
  }
end

function M.put_line(buf, text, fg_code)
  local row = {}
  local col = 1
  local i = 1
  text = tostring(text or "")
  while i <= #text and col <= buf.tw do
    local c = text:sub(i, i)
    if c == "\27" then
      local seq = text:sub(i):match("^(\27%[[0-9;:?]*m)")
      if seq then i = i + #seq -- estilo já embutido no texto; células usam fg_code
      else i = i + 1 end
    else
      local ok, cp = pcall(utf8.codepoint, text, i)
      local ch = (ok and cp) and utf8.char(cp) or c
      row[col] = { glifo = ch, fg = fg_code, bg = buf.bg }
      col = col + 1
      i = i + #ch
    end
  end
  while col <= buf.tw do
    row[col] = { glifo = " ", fg = fg_code, bg = buf.bg }
    col = col + 1
  end
  buf.cells[#buf.cells + 1] = row
end

function M.render(buf)
  local lines = {}
  local bg = estilo.sgr_bg(buf.bg)
  for _, row in ipairs(buf.cells) do
    local parts = { bg }
    local last_fg = nil
    for c = 1, buf.tw do
      local cell = row[c] or { glifo = " ", fg = nil, bg = buf.bg }
      if cell.fg ~= last_fg then
        parts[#parts + 1] = estilo.sgr_fg(cell.fg)
        last_fg = cell.fg
      end
      parts[#parts + 1] = cell.glifo
    end
    parts[#parts + 1] = estilo.reset()
    lines[#lines + 1] = table.concat(parts)
  end
  return lines
end

return M
