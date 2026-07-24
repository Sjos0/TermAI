-- banners.lua — Banners visuais do agente.
-- flush() agora aceita preview opcional para mostrar "Mensagem na fila".
-- v2: compactacao() parou de mostrar "próximo flush"/"a cada X tokens"
-- (informação do Memory Flush, sistema diferente) — agora mostra tokens
-- atuais e o limite real da compactação (context_window - reserve_tokens).

local mf = require("memoryflush")
local M  = {}

function M.flush(tokens, mf_cfg, preview)
  local linha  = string.rep("━", 50)
  local estado = mf.estado(tokens, mf_cfg)
  io.write("\n\27[38;5;220m" .. linha .. "\27[0m\n")
  io.write("\27[1m\27[38;5;220m 🧠 MEMORY FLUSH AUTOMÁTICO\27[0m\n")
  io.write(string.format(
    "\27[38;5;245m tokens agora : %d\n próximo flush: %d\n (a cada %d tokens)\27[0m\n",
    tokens, estado.proximo, estado.limite))
  if preview then
    io.write("\27[38;5;245m 📨 Mensagem na fila: \27[38;5;255m"
      .. preview .. "\27[0m\n")
  end
  io.write("\27[38;5;220m" .. linha .. "\27[0m\n\n")
  io.flush()
end

function M.compactacao(tokens, mf_cfg)
  local linha   = string.rep("━", 50)
  local limites = mf_cfg.limites or {}
  local reserva = limites.reserve_tokens or 16384
  local limite  = (mf_cfg.max_contexto or 0) - reserva
  io.write("\n\27[38;5;203m" .. linha .. "\27[0m\n")
  io.write("\27[1m\27[38;5;203m 🔄 COMPACTAÇÃO DE CONTEXTO\27[0m\n")
  io.write(string.format(
    "\27[38;5;245m tokens agora    : %d\n limite (reserva): %d\27[0m\n",
    tokens, limite))
  io.write("\27[38;5;203m" .. linha .. "\27[0m\n\n")
  io.flush()
end

return M
