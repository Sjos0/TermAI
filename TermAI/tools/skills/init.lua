-- tools/skills/init.lua — Orquestrador central do sistema de Skills.
-- Coordena discovery, parser, catalog e execucao da ferramenta "skill".
-- Nao contem logica de instalacao (essa vive em installer.lua — spec 08).
--
-- Modelo: gitlawb/mimo-v2.5-pro
-- Primeira feature planejada diretamente do Terminal (Termux/Android)
-- Autor: Samuel Rosa + Ameno | Data: 2026-05-25

local utils     = require("tools.skills.utils")
local parser    = require("tools.skills.parser")
local discovery = require("tools.skills.discovery")
local catalog   = require("tools.skills.catalog")

local M = {}

-- ── execute_skill ───────────────────────────────────────────────────────────
-- Carrega o SKILL.md de uma skill pelo nome e retorna o conteudo completo
-- como resposta da ferramenta. Inclui nome, diretorio base, body e dependencias.
-- Se a skill nao existir, retorna mensagem de erro.
function M.execute_skill(skill_name, agent_name)
  if not skill_name or skill_name == "" then
    return "❌ Nome da skill nao fornecido. Use: skill|nome_da_skill"
  end

  -- Sanitizar nome da skill (apenas minusculas, numeros e hifens)
  if not skill_name:match("^[%w%-]+$") then
    return "❌ Nome de skill invalido: '" .. skill_name .. "'. Use apenas minusculas, numeros e hifens."
  end

  -- Tentar primeiro no diretorio do agente, depois no global
  local agent_dir = utils.get_skills_dir(agent_name)
  local global_dir = utils.get_global_skills_dir()

  local skill_file = nil
  local base_dir = nil

  -- Busca 1: diretorio do agente
  local candidate = agent_dir .. "/" .. skill_name .. "/SKILL.md"
  if utils.file_exists(candidate) then
    skill_file = candidate
    base_dir   = agent_dir .. "/" .. skill_name
  end

  -- Busca 2: diretorio global (fallback)
  if not skill_file then
    candidate = global_dir .. "/" .. skill_name .. "/SKILL.md"
    if utils.file_exists(candidate) then
      skill_file = candidate
      base_dir   = global_dir .. "/" .. skill_name
    end
  end

  if not skill_file then
    return "❌ Skill '" .. skill_name .. "' nao encontrada. "
      .. "Verifique o nome ou instale via TermAI config > Agente > Skills."
  end

  -- Ler e parsear
  local f = io.open(skill_file, "r")
  if not f then
    return "❌ Erro ao abrir: " .. skill_file
  end
  local content = f:read("*a")
  f:close()

  local result, err = parser.parse(content)
  if not result then
    return "❌ Erro no parse de '" .. skill_name .. "': " .. (err or "erro desconhecido")
  end

  -- Montar resposta para o modelo
  local parts = {}
  parts[#parts + 1] = "## Skill: " .. result.name
  parts[#parts + 1] = "**Descricao:** " .. result.description
  parts[#parts + 1] = "**Diretorio base:** " .. base_dir
  parts[#parts + 1] = ""
  parts[#parts + 1] = result.body

  -- Se tem metadata com dependencias, listar
  if result.metadata and result.metadata.requires then
    local req = result.metadata.requires
    if req.bins and type(req.bins) == "table" then
      parts[#parts + 1] = ""
      parts[#parts + 1] = "**Dependencias de sistema:** " .. table.concat(req.bins, ", ")
    end
  end

  return table.concat(parts, "\n")
end

-- ── build_catalog ───────────────────────────────────────────────────────────
-- Gera o catalogo XML de skills para injetar no system prompt.
-- Escaneia o diretorio do agente ativo e monta o XML.
-- Se nao houver skills, retorna string vazia.
function M.build_catalog(agent_name)
  local skills_list = discovery.scan_agent(agent_name or "main")
  return catalog.build(skills_list)
end

return M
