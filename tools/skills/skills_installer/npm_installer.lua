-- tools/skills/skills_installer/npm_installer.lua — Orquestração de instalação de skills via NPM.
local npm_fetcher = require("tools.skills.skills_installer.npm_fetcher")
local installer   = require("tools.skills.skills_installer.installer")

local M = {}

-- Instala uma skill do npm
function M.install_npm(skill_name, dest, update)
  -- Verificar se ja existe
  if not update then
    local check = io.open(dest .. "/" .. skill_name .. "/SKILL.md", "r")
    if check then
      check:close()
      return "skip", "Skill ja instalada"
    end
  end

  -- Descobrir versao
  local version, err = npm_fetcher.resolve_version(skill_name)
  if not version then
    return "fail", err
  end

  -- Baixar .tgz
  local tarball, err2 = npm_fetcher.download(skill_name, version, dest)
  if not tarball then
    return "fail", err2
  end

  -- Extrair e instalar
  local ok, path = installer.install_from_tarball(tarball, skill_name, dest)
  os.remove(tarball)

  if ok then
    return "ok", path
  else
    return "fail", path
  end
end

return M
