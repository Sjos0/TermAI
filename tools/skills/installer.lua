-- tools/skills/installer.lua — Instalador de Skills.
-- Gerencia instalacao e remocao de skills entre diretorio global e agente.
-- Copia pastas inteiras (SKILL.md + scripts + references + assets).
--
-- Modelo: gitlawb/mimo-v2.5-pro
-- Primeira feature planejada diretamente do Terminal (Termux/Android)
-- Autor: Samuel Rosa + Ameno | Data: 2026-05-25

local utils     = require("tools.skills.utils")
local discovery = require("tools.skills.discovery")

local M = {}

-- ── list_global_skills ──────────────────────────────────────────────────────
-- Lista skills disponiveis no diretorio global.
-- Retorna lista de {name, description}.
function M.list_global_skills()
  local skills = discovery.scan_global()
  local list = {}
  for _, s in ipairs(skills) do
    list[#list + 1] = { name = s.name, description = s.description }
  end
  return list
end

-- ── list_agent_skills ───────────────────────────────────────────────────────
-- Lista skills ja instaladas no agente.
-- Retorna lista de {name, description}.
function M.list_agent_skills(agent_name)
  local skills = discovery.scan_agent(agent_name or "main")
  local list = {}
  for _, s in ipairs(skills) do
    list[#list + 1] = { name = s.name, description = s.description }
  end
  return list
end

-- ── install_to_agent ────────────────────────────────────────────────────────
-- Copia skills globais para o diretorio do agente.
-- Copia pastas inteiras recursivamente.
-- Retorna relatorio do que foi copiado.
function M.install_to_agent(skill_names, agent_name)
  if not skill_names or #skill_names == 0 then
    return "❌ Nenhuma skill selecionada."
  end

  agent_name = agent_name or "main"
  local global_dir = utils.get_global_skills_dir()
  local agent_dir  = utils.get_skills_dir(agent_name)
  local reports = {}

  -- Garantir que o diretorio do agente existe
  utils.ensure_dir(agent_dir)

  for _, name in ipairs(skill_names) do
    local src = global_dir .. "/" .. name
    local dst = agent_dir .. "/" .. name

    -- Verificar se a skill global existe
    if not utils.file_exists(src .. "/SKILL.md") then
      reports[#reports + 1] = "❌ '" .. name .. "': nao encontrada em skills globais"
    else
      -- Copiar recursivamente
      local safe_src = src:gsub("'", "'\\''")
      local safe_dst = dst:gsub("'", "'\\''")
      local cmd = "cp -r '" .. safe_src .. "' '" .. safe_dst .. "' 2>&1"
      local h = io.popen(cmd)
      local err = h and h:read("*a") or ""
      if h then h:close() end

      if err:match("^%s*$") then
        reports[#reports + 1] = "✅ '" .. name .. "': instalada com sucesso"
      else
        reports[#reports + 1] = "❌ '" .. name .. "': erro ao copiar — " .. err:match("^%s*(.-)%s*$")
      end
    end
  end

  return table.concat(reports, "\n")
end

-- ── uninstall_from_agent ────────────────────────────────────────────────────
-- Remove skills do diretorio do agente.
-- NAO remove do diretorio global.
-- Retorna relatorio do que foi removido.
function M.uninstall_from_agent(skill_names, agent_name)
  if not skill_names or #skill_names == 0 then
    return "❌ Nenhuma skill selecionada."
  end

  agent_name = agent_name or "main"
  local agent_dir = utils.get_skills_dir(agent_name)
  local reports = {}

  for _, name in ipairs(skill_names) do
    local path = agent_dir .. "/" .. name

    if not utils.file_exists(path) then
      reports[#reports + 1] = "❌ '" .. name .. "': nao encontrada no agente"
    else
      local safe = path:gsub("'", "'\\''")
      os.execute("rm -rf '" .. safe .. "'")
      reports[#reports + 1] = "✅ '" .. name .. "': removida do agente"
    end
  end

  return table.concat(reports, "\n")
end

return M
