-- tools/skills/skills_installer/utils.lua — Utilitários de caminho compartilhados.
-- Destino canônico delega ao SSOT em tools.skills.utils (mesmo par que
-- execute_skill / discovery / menus já usam). Não grava em agents/.

local skills_utils = require("tools.skills.utils")

local M = {}

-- Espera `parsed.flags` como argumento: { agent = nil | string, global = bool }
-- - com flags.agent → workspace do agente (main → workspace/skills)
-- - sem agent → skills globais (~/.TermAI/skills)
function M.get_dest(flags)
  flags = flags or {}
  if flags.agent then
    return skills_utils.get_skills_dir(flags.agent)
  end
  return skills_utils.get_global_skills_dir()
end

return M
