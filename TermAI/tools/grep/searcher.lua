local M = {}

local function glob_to_pattern(glob)
  -- Escapa caracteres mágicos do Lua pattern, depois converte '*' em '.*'
  local p = glob:gsub("[%^%$%(%)%%%.%[%]%+%-%?]", "%%%1")
  p = p:gsub("[*]", ".*") -- converte '*' em '.*'
  return "^" .. p .. "$"
end

local function is_binary(file_path)
  local f = io.open(file_path, "rb")
  if not f then return true end
  local bytes = f:read(1024)
  f:close()
  if not bytes then return false end
  return bytes:find("\0", 1, true) ~= nil
end

function M.execute(opts)
  local pattern = opts.pattern
  local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
  local base_path = opts.path or (HOME .. "/TermAI")
  local include_glob = opts.include

  local include_pat
  if include_glob and include_glob ~= "" then
    include_pat = glob_to_pattern(include_glob)
  end

  -- Usa find do Unix para listar arquivos recursivamente de forma ultrarápida
  -- Ignora explicitamente pastas ocultas de dados/controle (.git, .TermAI)
  local cmd = string.format("find %s -type f -not -path '*/.*' 2>/dev/null", string.format("%q", base_path))
  local h = io.popen(cmd)
  if not h then
    return nil, "Erro ao listar arquivos com find."
  end

  local files = {}
  for file in h:lines() do
    local clean_file = file:gsub("^%./", "")
    local matches_filter = true
    if include_pat then
      local filename = clean_file:match("([^/]+)$") or clean_file
      if not filename:match(include_pat) and not clean_file:match(include_pat) then
        matches_filter = false
      end
    end

    if matches_filter and not is_binary(file) then
      files[#files + 1] = file
    end
  end
  h:close()

  -- Ordena caminhos para manter o output deterministicamente arrumado
  table.sort(files)

  local matches = {}
  local match_count = 0
  local max_results = 100
  local truncated = false

  for _, file_path in ipairs(files) do
    if match_count >= max_results then
      truncated = true
      break
    end

    local f = io.open(file_path, "r")
    if f then
      local content = f:read("*a")
      f:close()

      if content and content ~= "" then
        local line_num = 0
        local has_trailing = content:sub(-1) == "\n"
        local temp = has_trailing and content:sub(1, -2) or content

        for line in (temp .. "\n"):gmatch("([^\n]*)\n") do
          line_num = line_num + 1

          -- Busca com robustez de Lua patterns (equivalente a regex nativa)
          local found = false
          local ok, res = pcall(string.find, line, pattern)
          if ok and res then
            found = true
          end

          if found then
            match_count = match_count + 1
            if match_count > max_results then
              truncated = true
              break
            end

            -- Truncamento de segurança por linha para evitar explosão de contexto
            if #line > 2000 then
              line = line:sub(1, 2000) .. " ... [Linha truncada: " .. (#line - 2000) .. " caracteres omitidos]"
            end

            if not matches[file_path] then
              matches[file_path] = {}
            end
            matches[file_path][#matches[file_path] + 1] = {
              line = line_num,
              text = line
            }
          end
        end
      end
    end
  end

  return {
    matches = matches,
    match_count = match_count,
    truncated = truncated,
    max_results = max_results
  }
end

return M
