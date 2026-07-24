local M = {}

-- Parseia URL do GitHub
-- Retorna: {owner, repo, path} ou nil
function M.parse_url(url)
  local owner, repo, path = url:match("github%.com/([^/]+)/([^/]+)(.*)")
  if not owner or not repo then return nil end
  path = path:gsub("^/", "")
  return { owner = owner, repo = repo, path = path }
end

-- Lista arquivos de um repositorio GitHub via API
-- Retorna: tabela de caminhos ou nil, error
function M.list_files(owner, repo, skill_name)
  local api_url = "https://api.github.com/repos/" .. owner .. "/" .. repo .. "/git/trees/main?recursive=1"
  local h = io.popen('curl -s --max-time 15 "' .. api_url .. '" 2>/dev/null')
  if not h then return nil, "falha ao executar curl" end
  local body = h:read("*a")
  h:close()

  if not body or body == "" then
    return nil, "Sem resposta do servidor"
  end
  if body:find("Not Found") then
    return nil, "Repositorio nao encontrado: " .. owner .. "/" .. repo
  end

  local all_files = {}
  for path in body:gmatch('"path"%s*:%s*"([^"]+)"') do
    all_files[#all_files + 1] = path
  end
  if #all_files == 0 then
    return nil, "Nenhum arquivo encontrado"
  end

  local files = {}
  if skill_name and skill_name ~= "" then
    for _, fp in ipairs(all_files) do
      -- Calcular o componente final do path (ultima parte apos a ultima barra)
      local segments = {}
      for seg in fp:gmatch("([^/]+)") do segments[#segments+1] = seg end
      local last_seg = segments[#segments] or ""

      -- Eh uma entrada de diretorio se:
      -- 1. O nome da skill e o ultimo segmento E
      -- 2. O path NAO contem barra DEPOIS do skill_name
      -- Ex: "skills/skill-creator" -> last_seg="skill-creator", eh diretorio
      -- Ex: "skills/skill-creator/SKILL.md" -> last_seg="SKILL.md", NAO eh diretorio
      local is_dir = (last_seg == skill_name) and (not fp:sub(#skill_name + 1):match("/"))

      if not is_dir then
        -- Verificar se o path contem a skill_name em algum segmento
        for _, seg in ipairs(segments) do
          if seg == skill_name then
            files[#files + 1] = fp
            break
          end
        end
      end
    end
  else
    files = all_files
  end

  if #files == 0 then
    return nil, "Nenhum arquivo encontrado para skill: " .. (skill_name or "?")
  end
  return files, nil
end

-- Baixa um arquivo do GitHub raw
function M.download_file(owner, repo, path)
  local raw_url = "https://raw.githubusercontent.com/" .. owner .. "/" .. repo .. "/main/" .. path
  local h = io.popen('curl -s --max-time 15 "' .. raw_url .. '" 2>/dev/null')
  if not h then return nil, "falha ao executar curl" end
  local content = h:read("*a")
  h:close()
  if not content or content == "" then
    return nil, "Arquivo vazio ou nao encontrado: " .. path
  end
  return content, nil
end

return M