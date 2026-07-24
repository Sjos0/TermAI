-- tools/skills/discovery.lua — Descoberta de Skills.
-- Escaneia diretorios de skills e retorna lista de skills disponiveis.
-- Cada skill e representada por {name, description, path, base_dir}.
-- Nao le o body do SKILL.md — so precisa de name + description para o catalogo.
--
-- Modelo: gitlawb/mimo-v2.5-pro
-- Primeira feature planejada diretamente do Terminal (Termux/Android)
-- Autor: Samuel Rosa + Ameno | Data: 2026-05-25

local utils  = require("tools.skills.utils")
local parser = require("tools.skills.parser")

local M = {}

-- ── scan ────────────────────────────────────────────────────────────────────
-- Escaneia um diretorio de skills e retorna lista de skills encontradas.
-- Se o diretorio nao existir, cria automaticamente (ensure_dir) e retorna {}.
-- Se um SKILL.md tiver erro de parse, loga warning e pula (nao quebra).
function M.scan(skills_dir)
  -- Garantir que o diretorio existe
  if not utils.file_exists(skills_dir) then
    utils.ensure_dir(skills_dir)
    return {}
  end

  local subdirs = utils.list_subdirs(skills_dir)
  local skills  = {}

  for _, dirname in ipairs(subdirs) do
    local skill_path = skills_dir .. "/" .. dirname
    local skill_file = skill_path .. "/SKILL.md"

    if utils.file_exists(skill_file) then
      local f = io.open(skill_file, "r")
      if f then
        local content = f:read("*a")
        f:close()

        local result, err = parser.parse(content)
        if result then
          skills[#skills + 1] = {
            name        = result.name,
            description = result.description,
            path        = skill_file,
            base_dir    = skill_path,
          }
        else
          -- Warning: skill com erro de parse — pular sem quebrar
          io.write("\27[38;5;220m⚠️  Skill '" .. dirname
            .. "' ignorada: " .. (err or "erro desconhecido") .. "\27[0m\n")
          io.flush()
        end
      end
    end
    -- Se SKILL.md nao existe na subpasta, simplesmente ignora
  end

  return skills
end

-- ── scan_global ─────────────────────────────────────────────────────────────
-- Escaneia o diretorio de skills globais (HOME/.TermAI/skills/).
-- Usado pelo installer para mostrar skills disponiveis para instalacao.
function M.scan_global()
  return M.scan(utils.get_global_skills_dir())
end

-- ── scan_agent ──────────────────────────────────────────────────────────────
-- Escaneia o diretorio de skills de um agente especifico.
-- Usado pelo catalogo para montar o XML de skills do agente ativo.
function M.scan_agent(agent_name)
  return M.scan(utils.get_skills_dir(agent_name))
end

return M
