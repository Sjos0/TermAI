-- ui/terminal_safe.lua — Garante restauração do terminal (stty sane) na saída
-- do processo, independente do caminho (os.exit, restart, erro fatal).
-- Encadeia com overrides existentes de os.exit (ex: ui/spinner/rotulo.lua):
-- o último instalado chama o anterior, preservando todos os cleanups.
--
-- stty sane SEM TTY pode travar no Termux (CI / headless). Só executa se
-- /dev/tty existir e com timeout curto quando `timeout` estiver no PATH.
local M = {}

local _installed = false

local function restaurar_terminal()
  local tty = io.open("/dev/tty", "r")
  if not tty then return end
  tty:close()
  -- timeout 1s evita hang eterno se stty bloquear; fallback sem timeout se não houver o binário.
  local ok = os.execute("command -v timeout >/dev/null 2>&1 && timeout 1 stty sane < /dev/tty 2>/dev/null")
  if not ok then
    os.execute("stty sane < /dev/tty 2>/dev/null")
  end
end

function M.install()
  if _installed then return end
  _installed = true
  local original_exit = os.exit
  os.exit = function(...)
    pcall(restaurar_terminal)
    return original_exit(...)
  end
end

return M
