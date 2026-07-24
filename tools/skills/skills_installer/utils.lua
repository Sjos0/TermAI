-- tools/skills/skills_installer/utils.lua — Utilitários de caminho compartilhados.
local M = {}

local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
M.HOME = HOME

-- Espera `parsed.flags` como argumento: { agent = nil | string, global = bool }
function M.get_dest(flags)
  if flags.agent then
    return HOME .. "/.TermAI/agents/" .. flags.agent .. "/skills"
  end
  return HOME .. "/.TermAI/skills"
end

return M
