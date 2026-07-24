-- tools/skills/skills_installer/cli.lua — Ponto de entrada CLI do instalador de skills (Padrão Fachada).
local parser           = require("tools.skills.skills_installer.parser")
local npm_installer    = require("tools.skills.skills_installer.npm_installer")
local github_installer = require("tools.skills.skills_installer.github_installer")
local ui               = require("tools.skills.skills_installer.ui")
local utils            = require("tools.skills.skills_installer.utils")

local M = {}

local RED   <const> = "\27[38;5;203m"
local RESET <const> = "\27[0m"

-- Detecta se a fonte e GitHub (URL ou "skills add")
local function is_github(source, url)
  return source == "skills" or (url and url:match("^https?://"))
end

function M.run(args)
  local parsed = parser.parse(args)

  -- Validar argumentos
  if not parsed.source then
    ui.usage()
    return
  end

  if #parsed.skills == 0 then
    io.write(RED .. "Erro: nenhuma skill especificada. Use --skill <nome>\n" .. RESET)
    ui.usage()
    return
  end

  -- Processar cada skill
  local dest = utils.get_dest(parsed.flags)
  local results = {}

  for _, skill_name in ipairs(parsed.skills) do
    ui.processing("Instalando " .. skill_name)

    local status, msg
    if is_github(parsed.source, parsed.url) then
      local url = parsed.url or parsed.source
      status, msg = github_installer.install_github(url, skill_name, dest, parsed.flags.update)
    else
      status, msg = npm_installer.install_npm(skill_name, dest, parsed.flags.update)
    end

    if status == "ok" then
      ui.result_ok(skill_name, msg)
    elseif status == "skip" then
      ui.result_skip(skill_name, msg)
    else
      ui.result_fail(skill_name, msg)
    end

    results[#results + 1] = { name = skill_name, status = status }
  end

  -- Resumo
  ui.summary(results)
end

return M
