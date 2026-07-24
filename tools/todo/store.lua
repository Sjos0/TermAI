-- tools/todo/store.lua — Persistência da lista de tarefas por sessão.
-- Grava em JSON ao lado do transcript da sessão, com escrita atômica (tmp + rename).
local json          = require("json")
local session_store = require("session.store")

local M = {}

local function path_for(session_id)
  return session_store.SESSIONS_DIR .. "/" .. session_id:gsub(":", "-") .. ".todos.json"
end

-- Salva a lista completa de todos para a sessão. Retorna true ou false+erro.
function M.save(session_id, todos)
  if not session_id or session_id == "" then
    return false, "session_id ausente"
  end

  local ok_enc, encoded = pcall(json.encode, todos)
  if not ok_enc then
    return false, "falha ao serializar: " .. tostring(encoded)
  end

  local final_path = path_for(session_id)
  local tmp_path    = final_path .. ".tmp"

  local f = io.open(tmp_path, "w")
  if not f then
    return false, "não foi possível abrir arquivo temporário"
  end
  f:write(encoded)
  f:close()

  local renamed, rename_err = os.rename(tmp_path, final_path)
  if not renamed then
    return false, "falha no rename atômico: " .. tostring(rename_err)
  end
  return true
end

-- Carrega a lista de todos da sessão. Retorna {} se não existir ou estiver corrompida.
function M.load(session_id)
  if not session_id or session_id == "" then return {} end

  local f = io.open(path_for(session_id), "r")
  if not f then return {} end
  local content = f:read("*a")
  f:close()

  local ok_dec, decoded = pcall(json.decode, content)
  if not ok_dec or type(decoded) ~= "table" then return {} end
  return decoded
end

-- Remove o arquivo de todos da sessão (chamado quando a lista é concluída).
function M.delete(session_id)
  if not session_id or session_id == "" then return false end
  local ok = os.remove(path_for(session_id))
  return ok == true
end

return M
