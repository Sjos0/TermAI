-- tools/grep/searcher/nucleo_1.lua — helpers internos: glob_to_pattern, is_binary, is_sensitive, shell_quote.
return function(M)
  local P = require("tools.grep.searcher.nucleo")(M)
  local SENSITIVE_NAMES = P.SENSITIVE_NAMES


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
  local N = {}
  for k, v in pairs(P) do N[k] = v end
  N.glob_to_pattern = glob_to_pattern
  N.is_binary = is_binary
  N.is_sensitive = is_sensitive
  N.shell_quote = shell_quote
  return N
end
