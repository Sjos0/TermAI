local M = {}

local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"

-- Extrai um .tgz e instala a skill na pasta de destino
function M.install_from_tarball(tarball_path, skill_name, dest_dir)
  dest_dir = dest_dir or HOME .. "/.TermAI/skills"
  os.execute('mkdir -p "' .. dest_dir .. '"')
  local tmp_extract = (os.getenv("TMPDIR") or "/data/data/com.termux/files/usr/tmp")
    .. "/termai_extract_" .. tostring(os.time())
  os.execute('mkdir -p "' .. tmp_extract .. '"')
  local h = io.popen('tar xzf "' .. tarball_path .. '" -C "' .. tmp_extract .. '" 2>&1')
  if h then h:close() end
  local skill_dir = tmp_extract .. "/package/" .. skill_name
  local ok2 = io.open(skill_dir .. "/SKILL.md", "r")
  if not ok2 then
    local find = io.popen('find "' .. tmp_extract .. '" -name "SKILL.md" -type f 2>/dev/null')
    if find then
      local found = find:read("*l")
      find:close()
      if found then skill_dir = found:gsub("/SKILL.md$", "") end
    end
  else ok2:close() end
  local check = io.open(skill_dir .. "/SKILL.md", "r")
  if not check then
    os.execute('rm -rf "' .. tmp_extract .. '"')
    return false, "SKILL.md nao encontrado no pacote"
  end
  check:close()
  local final_dir = dest_dir .. "/" .. skill_name
  os.execute('rm -rf "' .. final_dir .. '"')
  os.execute('cp -r "' .. skill_dir .. '" "' .. final_dir .. '"')
  os.execute('rm -rf "' .. tmp_extract .. '"')
  local verify = io.open(final_dir .. "/SKILL.md", "r")
  if not verify then return false, "Falha ao copiar" end
  verify:close()
  return true, final_dir
end

-- Salva arquivos baixados do GitHub na pasta de destino
-- files_map: {path = conteudo}
-- files_list: lista de paths do repositorio
-- skill_name: nome da skill
function M.install_from_files(files_map, files_list, skill_name, dest_dir)
  dest_dir = dest_dir or HOME .. "/.TermAI/skills"
  local final_dir = dest_dir .. "/" .. skill_name
  os.execute('rm -rf "' .. final_dir .. '"')

  local base_path = nil
  for _, path in ipairs(files_list) do
    if path:find(skill_name, 1, true) and path:find("SKILL.md", 1, true) then
      base_path = path:gsub("/SKILL.md$", "")
      break
    end
  end
  if not base_path then
    return false, "Pasta da skill '" .. skill_name .. "' nao encontrada"
  end

  -- Extensoes validas para arquivos
  local valid_ext = {
    [".md"]=true, [".lua"]=true, [".py"]=true,
    [".html"]=true, [".json"]=true, [".js"]=true,
    [".txt"]=true, [".sh"]=true, [".yaml"]=true,
    [".yml"]=true, [".toml"]=true, [".cfg"]=true,
    [".css"]=true, [".rs"]=true, [".go"]=true,
  }
  local count = 0
  for _, path in ipairs(files_list) do
    if path:sub(1, #base_path) == base_path then
      local rel = path:sub(#base_path + 1)
      if rel:sub(1, 1) == "/" then rel = rel:sub(2) end
      if rel ~= "" then
        -- Pular paths sem extensao (entradas de diretorio do GitHub)
        local ext = rel:match("%.([^%.]+)$") or ""
        if ext ~= "" then
          local full_path = final_dir .. "/" .. rel
          local dir = full_path:gsub("/[^/]+$", "")
          os.execute('mkdir -p "' .. dir .. '"')
          local content = files_map[path]
          if content and #content > 0 then
            local f = io.open(full_path, "w")
            if f then f:write(content); f:close(); count = count + 1 end
          end
        end
      end
    end
  end
  if count == 0 then
    os.execute('rm -rf "' .. final_dir .. '"')
    return false, "Nenhum arquivo salvo"
  end
  return true, final_dir
end

return M
