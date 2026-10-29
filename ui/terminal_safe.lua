-- ui/terminal_safe.lua — Garante restauração do terminal (stty sane) na saída
-- do processo, independente do caminho (os.exit, restart, erro fatal).
-- Encadeia com overrides existentes de os.exit (ex: ui/spinner/rotulo.lua):
-- o último instalado chama o anterior, preservando todos os cleanups.
--
-- Com /dev/tty: stty sane no TTY, com timeout 1s quando disponível (anti-hang).
-- Sem /dev/tty (CI/headless): ainda tenta `stty sane 2>/dev/null` (falha rápido).
local M = {}

local _installed = false

local function has_timeout_bin()
  local r = os.execute("command -v timeout >/dev/null 2>&1")
  return r == true or r == 0
end

local function restaurar_terminal()
  local tty = io.open("/dev/tty", "r")
  if tty then
    tty:close()
    if has_timeout_bin() then
      os.execute("timeout 1 stty sane < /dev/tty 2>/dev/null")
    else
      os.execute("stty sane < /dev/tty 2>/dev/null")
    end
    return
  end
  -- Headless/CI: mock de teste intercepta; no host real falha rápido sem TTY.
  os.execute("stty sane 2>/dev/null")
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
