-- tools/skills/utils.lua — Helpers compartilhados do sistema de Skills.
-- Resolve caminhos, detecta home do usuario, lista diretorios e verifica arquivos.
-- Reutiliza HOME e PROJECT_ROOT do helpers.lua (Single Source of Truth).
--
-- Modelo: gitlawb/mimo-v2.5-pro
-- Primeira feature planejada diretamente do Terminal (Termux/Android)
-- Autor: Samuel Rosa + Ameno | Data: 2026-05-25

local helpers = require("tools.helpers")

local M = {}

-- HOME e PROJECT_ROOT vêm do helpers.lua — nunca recalcular aqui.
local HOME         = helpers.PROJECT_ROOT:match("^(.+)/%.TermAI$")
                    or os.getenv("HOME")
                    or "/data/data/com.termux/files/home"
local PROJECT_ROOT = helpers.PROJECT_ROOT

-- ── get_home ────────────────────────────────────────────────────────────────
-- Retorna o diretorio home do usuario (dinamico, nunca hardcoded).
function M.get_home()
  return HOME
end

-- ── get_skills_dir ──────────────────────────────────────────────────────────
-- Retorna o diretorio de skills para um agente especifico.
-- Se agent_name for nil, retorna o diretorio de skills do agente main (flat).
function M.get_skills_dir(agent_name)
  if agent_name and agent_name ~= "main" then
    return PROJECT_ROOT .. "/workspace/" .. agent_name .. "/skills"
  end
  -- Agente main: flat — workspace e o proprio agente
  return PROJECT_ROOT .. "/workspace/skills"
end

-- ── get_global_skills_dir ───────────────────────────────────────────────────
-- Retorna o diretorio de skills globais (HOME/.TermAI/skills/).
function M.get_global_skills_dir()
  return PROJECT_ROOT .. "/skills"
end

-- ── ensure_dir ──────────────────────────────────────────────────────────────
-- Cria o diretorio se nao existir (mkdir -p).
-- Retorna true se o diretorio existe (ou foi criado), false se falhou.
function M.ensure_dir(path)
  local safe = path:gsub("'", "'\\''")
  os.execute("mkdir -p '" .. safe .. "'")
  local f = io.open(path, "r")
  if f then f:close(); return true end
  return false
end

-- ── list_subdirs ────────────────────────────────────────────────────────────
-- Lista subpastas de um diretorio.
-- Retorna tabela de nomes (strings). Retorna {} se diretorio nao existe.
function M.list_subdirs(path)
  local dirs = {}
  local h = io.popen('ls -d "' .. path .. '"/*/ 2>/dev/null')
  if not h then return dirs end
  local output = h:read("*a") or ""
  h:close()
  for line in output:gmatch("[^\n]+") do
    -- Extrai apenas o nome da pasta (remove path e barra final)
    local name = line:match("([^/]+)/?$")
    if name and name ~= "" then
      dirs[#dirs + 1] = name
    end
  end
  return dirs
end

-- ── file_exists ─────────────────────────────────────────────────────────────
-- Verifica se um arquivo existe e pode ser lido.
-- Retorna boolean.
function M.file_exists(path)
  local f = io.open(path, "r")
  if not f then return false end
  f:close()
  return true
end

return M
