-- agent/api/summarizer/ui.lua — Renderização e animação do rodapé da TUI durante a condensação.
local M = {}

-- Obtém o tempo real do sistema com precisão de milissegundos
function M.get_wall_time()
  local f = io.open("/proc/uptime", "r")
  if not f then return os.time() end
  local val = f:read("*n")
  f:close()
  return val or os.time()
end

-- Renderiza a barra de progresso temporária vermelha no rodapé
function M.render_red_footer(tokens, window, elapsed_secs, anim_text)
  local elapsed = elapsed_secs and string.format(" | %ds", elapsed_secs) or ""
  local now_time = os.date("%H:%M")
  local pct = (tokens / window) * 100

  local red_color = "\27[38;5;203m"
  local reset = "\27[0m"
  local clear_line = "\27[K" -- limpa resíduos à direita do cursor

  io.write(string.format("\r%stokens: %d/%d (%.1f%%)%s | %s %s%s%s",
    red_color, tokens, window, pct, elapsed, now_time, anim_text, reset, clear_line))
  io.flush()
end

return M
