local pattern_mod = require("tools.grep.pattern")
local redact      = require("tools.subagents.redact")

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

-- Arquivos que nunca vão para o modelo, mesmo dentro de pastas do TermAI:
-- config.json tem chaves de API; tokens, chaves e .env são segredos por nome.
local SENSITIVE_NAMES = { ["config.json"] = true }
local function is_sensitive(rel)
  local name = (rel:match("([^/]+)$") or rel):lower()
  if SENSITIVE_NAMES[name] then return true end
  if name:match("^%.env") or name:match("%.key$") or name:match("%.pem$") then return true end
  if name:match("token") or name:match("secret") or name:match("credential") then return true end
  return false
end

-- Aspas simples com escape: um diretório com $ ou aspas não vira comando.
local function shell_quote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

function M.execute(opts)
  local pattern = opts.pattern or ""
  local perr = pattern_mod.validate(pattern)
  if perr then
    return nil, "padrão Lua inválido: " .. perr .. ". Lua patterns não são regex; escape caracteres mágicos com %."
  end

  local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
  local base_path = opts.path or (HOME .. "/TermAI")
  local include_glob = opts.include

  local include_pat
  if include_glob and include_glob ~= "" then
    include_pat = glob_to_pattern(include_glob)
  end

  -- find roda DENTRO do base: o filtro de ocultos vale só para subcaminhos. Antes, o predicado
  -- casava o próprio caminho do base, e um base oculto (ex.: ~/.TermAI) ficava invisível.
  -- .git é sempre excluído: pode conter URL com token.
  local cmd = string.format(
    "cd %s && find . -type f -not -path '*/.*' -not -path './.git/*' 2>/dev/null",
    shell_quote(base_path))
  local h = io.popen(cmd)
  if not h then
    return nil, "Erro ao listar arquivos com find."
  end

  local files = {}
  for file in h:lines() do
    local rel = file:gsub("^%./", "")
    local matches_filter = true
    if include_pat then
      local filename = rel:match("([^/]+)$") or rel
      if not filename:match(include_pat) and not rel:match(include_pat) then
        matches_filter = false
      end
    end
    if matches_filter and not is_sensitive(rel) then
      local full = base_path .. "/" .. rel
      if not is_binary(full) then files[#files + 1] = full end
    end
  end
  h:close()

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

          -- Erro de pattern não é "não encontrado": falha alto (já validado acima; isto cobre o resto).
          local ok, res = pcall(string.find, line, pattern)
          if not ok then
            return nil, "padrão Lua inválido: " .. tostring(res)
          end

          if res then
            match_count = match_count + 1
            if match_count > max_results then
              truncated = true
              break
            end

            -- Mascara segredos antes de mostrar; depois trunca para não explodir o contexto.
            local shown = redact.clean(line)
            if #shown > 2000 then
              shown = shown:sub(1, 2000) .. " ... [Linha truncada: " .. (#shown - 2000) .. " caracteres omitidos]"
            end

            if not matches[file_path] then
              matches[file_path] = {}
            end
            matches[file_path][#matches[file_path] + 1] = {
              line = line_num,
              text = shown
            }
          end
        end
      end
    end
  end

  local hint = nil
  if match_count == 0 and pattern_mod.has_alternation(pattern) then
    hint = "'|' não é alternância em Lua pattern: é um caractere literal. Faça uma busca por termo (ex.: uma para 'alpha' e outra para 'beta')."
  end

  return {
    matches = matches,
    match_count = match_count,
    truncated = truncated,
    max_results = max_results,
    hint = hint,
  }
end

return M
