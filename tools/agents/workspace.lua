-- tools/agents/workspace.lua — Grava os arquivos de identidade de um agente independente.
local paths = require("tools.agents.paths")
local M = {}

local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return content
end

local function write_file(path, content)
  local f, err = io.open(path, "w")
  if not f then return false, err end
  f:write(content or "")
  f:close()
  return true
end

-- Cria o workspace: IDENTITY.md (nome + identidade), AGENTS.md (funções) e USER.md (cópia do orquestrador).
function M.create(id, nome, identidade, funcoes)
  local dir = paths.workspace_abs(id)
  os.execute(string.format("mkdir -p '%s'", dir))

  local user = read_file(paths.main_user_md()) or ""
  local identity = "# " .. (nome or id) .. "\n\n" .. identidade .. "\n"

  local ok1 = write_file(dir .. "/IDENTITY.md", identity)
  local ok2 = write_file(dir .. "/AGENTS.md", funcoes .. "\n")
  local ok3 = write_file(dir .. "/USER.md", user)
  if not (ok1 and ok2 and ok3) then
    return false, "falha ao gravar arquivos em " .. dir
  end
  return true, dir
end

-- Remove o workspace inteiro do agente (usado para desfazer uma criação que falhou).
function M.remove(id)
  os.execute(string.format("rm -rf '%s'", paths.root() .. "/agents/" .. id))
end

return M
