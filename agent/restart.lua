-- agent/restart.lua — Gerencia reinício limpo da TUI.
-- Estratégia: pending_restart em memória (sem I/O de disco).
-- Quando pendente, check() chama restart_now() após save_exchange().

local M = {}

-- Estado em memória: compartilhado entre M.request() e M.check()
-- porque ambos vivem no mesmo processo Lua.
local pending_restart = false

local function do_restart()
  -- AUDIT TRAIL: Registra o evento no histórico para a IA ter consciência situacional
  local session = require("session")
  pcall(function()
    session.save_message("system", "[SYSTEM_AUDIT] O sistema foi reiniciado intencionalmente para atualização de estado/configuração.", 0, true)
  end)

  io.write("\n\27[38;5;114m🔄 Reiniciando TermAI...\27[0m\n\n")
  io.flush()
  io.write("\27[?1049l"); io.flush()
  io.write("\27[?2004l"); io.flush()
  os.execute("stty sane 2>/dev/null")
  os.exit(123)
end

function M.request()
  pending_restart = true
  return true
end

function M.check()
  if not pending_restart then return false end
  -- Limpa ANTES de chamar do_restart() para evitar loop infinito
  -- caso os.exit() falhe silenciosamente (edge case).
  pending_restart = false
  do_restart()
  return false
end

function M.restart_now()
  do_restart()
end

return M