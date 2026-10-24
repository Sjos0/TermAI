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
-- Buffer vazio (nada digitado): só então é seguro acordar o orquestrador.
local function is_empty(segs)
  return (seg.get_input(segs) or "") == ""
end

-- opts.on_idle(buffer_vazio) é chamado a cada ~1 s sem tecla. Devolver true acorda o orquestrador
-- (M.read retorna "", {}, "", true). Sem opts, o comportamento é o bloqueante de sempre.
function M.read(opts)
  local poll = opts and opts.on_idle
  if poll then
    os.execute("stty raw -echo min 0 time 10 2>/dev/null")
  else
    os.execute("stty raw -echo 2>/dev/null")
  end

  -- Ativa bracketed paste mode
  io.write("\27[?2004h")
  io.flush()

  core.invalidate_size()

  local segments   = {}
  local prev_lines = 0
  -- Largura 0 (terminal sem tamanho) faria a divisão virar infinito no redesenho.
  local tw = core.tw()
  if not tw or tw < 20 then tw = 80 end

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

  local wake = false
  local ok, _ = pcall(function()
    redraw()

    while true do
      local byte = io.read(1)
      if not byte and poll then
        -- Acordar só com buffer vazio: nunca descarta o que o usuário está digitando.
        local empty = is_empty(segments)
        if poll(empty) and empty then wake = true; break end
      elseif not byte then
        break
      end
      if byte then
      local code = byte:byte()

      if code == 13 or code == 10 then
        break

      elseif code == 3 or code == 4 then
        segments = {}
        break

      elseif code == 15 then
        -- Ctrl+O: expande o corpo do último card (append-only); só o prompt é redesenhado.
        if require("ui.tools_init.default_body").expand() then redraw() end

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
  if wake then return "", {}, "", true end
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
