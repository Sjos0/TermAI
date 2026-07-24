local M = {}

-- Resolve a versao mais recente de um pacote npm
-- Retorna: version (string) ou nil, error (string)
function M.resolve_version(package)
  local url = "https://registry.npmjs.org/" .. package .. "/latest"
  local h = io.popen('curl -s --max-time 15 "' .. url .. '" 2>/dev/null')
  if not h then return nil, "falha ao executar curl" end
  local body = h:read("*a")
  h:close()

  if not body or body == "" then
    return nil, "Sem resposta do servidor"
  end

  -- Tentar decode JSON basico
  local version = body:match('"version"%s*:%s*"([^"]+)"')
  if not version then
    if body:find("Not Found") then
      return nil, "Pacote nao encontrado: " .. package
    end
    return nil, "Formato de resposta inesperado"
  end

  return version, nil
end

-- Baixa o .tgz de um pacote npm
-- Retorna: caminho do arquivo (string) ou nil, error (string)
function M.download(package, version, dest_dir)
  local tarball_name = package:gsub("/", "-")
  if tarball_name:sub(1, 1) == "@" then
    tarball_name = tarball_name:sub(2)
  end
  local url = "https://registry.npmjs.org/" .. package .. "/-/" .. tarball_name .. "-" .. version .. ".tgz"
  local tmpfile = os.getenv("TMPDIR") or "/data/data/com.termux/files/usr/tmp"
  tmpfile = tmpfile .. "/termai_skill_" .. tostring(os.time()) .. ".tgz"

  local h = io.popen('curl -sL --max-time 30 "' .. url .. '" -o "' .. tmpfile .. '" 2>/dev/null')
  if h then h:close() end

  -- Verificar se o arquivo foi criado e tem tamanho > 0
  local f = io.open(tmpfile, "rb")
  if not f then
    return nil, "Falha ao baixar: " .. url
  end
  local size = f:seek("end")
  f:close()

  if not size or size == 0 then
    os.remove(tmpfile)
    if not version then
      return nil, "Pacote nao encontrado: " .. package
    end
    return nil, "Falha ao baixar: " .. url
  end

  return tmpfile, nil
end

return M