-- ui/terminal_safe.lua — Garante restauração do terminal (stty sane) na saída
-- do processo, independente do caminho (os.exit, restart, erro fatal).
-- Encadeia com overrides existentes de os.exit (ex: ui/spinner/rotulo.lua):
-- o último instalado chama o anterior, preservando todos os cleanups.
local M = {}

local _installed = false

function M.install()
  if _installed then return end
  _installed = true
  local original_exit = os.exit
  os.exit = function(...)
    pcall(function() os.execute("stty sane 2>/dev/null") end)
    return original_exit(...)
  end
end

return M
