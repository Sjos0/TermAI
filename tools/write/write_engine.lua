-- tools/write/write_engine.lua — Logica de escrita de arquivos.
-- Extraido de editor.lua para modularizacao.
-- Autor: Ameno | Data: 2026-05-30 | Refatoracao editor-lua

local val = require("tools.editor.validator")

local M = {}

local function ensure_dir(path)
  local dir = path:match("^(.+)/[^/]+$")
  if not dir then return end
  local safe = dir:gsub("'", "'\\''")
  os.execute("mkdir -p '" .. safe .. "'")
end

local function write_file(path, content)
  local f = io.open(path, "w")
  if not f then return false, "falha ao abrir para escrita: " .. path end
  f:write(content)
  f:close()
  return true
end

-- Escreve arquivo com validacao de sintaxe Lua.
-- Se .lua, roda luac -p apos escrita. Se falhar, retorna erro.
function M.write_safe(path, content)
  ensure_dir(path)
  local ok, err = write_file(path, content)
  if not ok then return false, err end

  local valid, lint_err = val.validate_lua(path)
  if not valid then
    return false, "Arquivo gravado mas com sintaxe invalida:\n" .. lint_err
  end

  return true
end

return M
