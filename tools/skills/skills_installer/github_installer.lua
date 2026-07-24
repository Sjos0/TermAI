-- tools/skills/skills_installer/github_installer.lua — Orquestração de instalação de skills via GitHub.
local github_fetcher = require("tools.skills.skills_installer.github_fetcher")
local installer      = require("tools.skills.skills_installer.installer")
local utils          = require("tools.skills.skills_installer.utils")

local M = {}

-- Instala uma skill do GitHub
function M.install_github(url, skill_name, dest, update)
  -- Verificar se ja existe
  if not update then
    local check = io.open(dest .. "/" .. skill_name .. "/SKILL.md", "r")
    if check then
      check:close()
      return "skip", "Skill ja instalada"
    end
  end

  -- Parsear URL
  local parsed = github_fetcher.parse_url(url)
  if not parsed then
    return "fail", "URL invalida: " .. url
  end

  -- Listar arquivos
  local files, err = github_fetcher.list_files(parsed.owner, parsed.repo, skill_name)
  if not files then
    return "fail", err
  end

  -- Baixar cada arquivo
  local files_map = {}
  for _, path in ipairs(files) do
    local content, err2 = github_fetcher.download_file(parsed.owner, parsed.repo, path)
    if content then
      files_map[path] = content
    end
  end

  -- Instalar (GitHub install é sempre global)
  local dest_dir = utils.get_dest({ agent = nil, global = true })
  files_map._owner = parsed.owner
  files_map._repo = parsed.repo
  local ok, path = installer.install_from_files(files_map, files, skill_name, dest_dir)
  if ok then
    return "ok", path
  else
    return "fail", path
  end
end

return M
