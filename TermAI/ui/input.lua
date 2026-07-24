-- input.lua — Fachada + Loop principal de input raw com suporte a bracketed paste.
-- Interface pública: M.read(), M.paste_counter, M.pasted_texts
-- ⚠️ stty raw/sane são operações atômicas fora do pcall — preservar ordem exata.
local core  = require("ui.core")
local c     = core.c
local width = require("ui.input.unicode_width")
local seg   = require("ui.input.segments")
local tread = require("ui.input.terminal_read")
local M = {}

-- ── Paste storage (acessível externamente se necessário) ───────────────────
M.paste_counter = 0
M.pasted_texts  = {}

-- ── M.read ─────────────────────────────────────────────────────────────────
function M.read()
  os.execute("stty raw -echo 2>/dev/null")

  -- Ativa bracketed paste mode
  io.write("\27[?2004h")
  io.flush()

  core.invalidate_size()

  local segments   = {}
  local prev_lines = 0
  local tw = core.tw()

  local function redraw()
    local display = seg.get_display(segments)
    if prev_lines > 0 then
      io.write(string.format("\27[%dA", prev_lines))
    end
    io.write("\r\27[J")
    io.write(c.bold .. "\27[38;5;39m❯\27[0m " .. display)
    io.flush()
    local plain = display:gsub("\27%[[0-9;]*m", "")
    local total = 2 + width.display_width(plain)
    prev_lines = math.max(0, math.floor((total - 1) / tw))
  end

  local ok, _ = pcall(function()
    redraw()

    while true do
      local byte = io.read(1)
      if not byte then break end
      local code = byte:byte()

      if code == 13 or code == 10 then
        break

      elseif code == 3 or code == 4 then
        segments = {}
        break

      elseif code == 27 then
        local kind, seq = tread.read_escape_seq()

        if kind == "csi" and seq == "200~" then
          local pasted = tread.read_bracketed_paste()
          if pasted ~= "" then
            M.paste_counter = M.paste_counter + 1
            M.pasted_texts[M.paste_counter] = pasted
            segments[#segments + 1] = {
              kind = "paste",
              val  = pasted,
              idx  = M.paste_counter,
            }
            redraw()
          end
        end

      elseif code == 127 or code == 8 then
        if seg.backspace(segments) then
          redraw()
        end

      elseif code >= 32 then
        local char = string.char(code)
        if code >= 0xC2 and code <= 0xDF then
          local b2 = io.read(1)
          if b2 then char = char .. b2 end
        elseif code >= 0xE0 and code <= 0xEF then
          local b2 = io.read(1); local b3 = io.read(1)
          if b2 then char = char .. b2 end
          if b3 then char = char .. b3 end
        elseif code >= 0xF0 then
          local b2 = io.read(1); local b3 = io.read(1); local b4 = io.read(1)
          if b2 then char = char .. b2 end
          if b3 then char = char .. b3 end
          if b4 then char = char .. b4 end
        end
        seg.append_char(segments, char)
        redraw()
      end
    end
  end)

  if prev_lines > 0 then
    io.write(string.format("\27[%dA", prev_lines))
  end
  io.write("\r\27[J")

  -- Desativa bracketed paste mode
  io.write("\27[?2004l")
  io.flush()

  os.execute("stty sane 2>/dev/null")

  if not ok then return "", {}, "" end
  local raw = seg.get_input(segments)

  -- Clona os pasted_texts para persistência física isolada
  local current_pastes = {}
  for k, v in pairs(M.pasted_texts) do
    current_pastes[tostring(k)] = v
  end

  -- Filtra cores ANSI para salvar o placeholder de forma limpa no histórico
  local placeholder_text = seg.get_display(segments):gsub("\27%[[0-9;]*m", "")

  -- Reseta contadores locais para o próximo input
  M.paste_counter = 0
  M.pasted_texts  = {}

  return placeholder_text, current_pastes, raw
end

return M
