local editor = {}

local function backup(path)
  os.execute("cp '"..path.."' '"..path..".bak' 2>/dev/null")
end

-- Substituição exata: só troca se o trecho existir UMA vez
function editor.replace_exact(path, old_text, new_text)
  local f = io.open(path, "r")
  if not f then return false, "arquivo não encontrado" end
  local content = f:read("*a"); f:close()

  if old_text == "" then return false, "texto antigo vazio" end

  local first = content:find(old_text, 1, true)
  if not first then return false, "texto não encontrado" end

  local second = content:find(old_text, first + 1, true)
  if second then return false, "texto aparece mais de 1 vez (use trecho maior)" end

  backup(path)
  local new_content = content:sub(1, first-1) .. new_text .. content:sub(first + #old_text)
  local fw = io.open(path, "w"); fw:write(new_content); fw:close()
  return true, "substituição exata aplicada"
end

-- Escrita segura com backup
function editor.write_safe(path, content)
  local dir = path:match("^(.+)/[^/]+$")
  if dir then os.execute("mkdir -p '"..dir.."'") end
  if io.open(path, "r") then backup(path) end
  local f = io.open(path, "w"); f:write(content); f:close()
  return true
end

return editor
