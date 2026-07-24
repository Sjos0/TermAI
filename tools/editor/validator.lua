-- tools/editor/validator.lua — Validacao de sintaxe Lua.
-- Extraido de editor.lua para modularizacao.
-- Autor: Ameno | Data: 2026-05-29 | Refatoracao editor-lua

local M = {}

-- Valida sintaxe de um arquivo Lua inteiro com luac -p.
-- Retorna: true (ok) ou false, mensagem_de_erro.
function M.validate_lua(path)
  if not path:match("%.lua$") then return true, nil end
  local h = io.popen('luac -p "' .. path:gsub('"', '\\"') .. '" 2>&1')
  if not h then return true, nil end
  local out = h:read("*a")
  h:close()
  out = out:match("^%s*(.-)%s*$")
  if out == "" then return true, nil end
  return false, out
end

-- Valida sintaxe de um trecho Lua isoladamente (PREVIA).
-- Envolve o fragmento em "return function() ... end" e roda luac -p.
-- Retorna: true (ok) ou false, mensagem_de_erro.
-- Diferencial do TermAI (OpenClaw nao tem validacao previa).
function M.validate_lua_fragment(fragment, path)
  if not path:match("%.lua$") then return true, nil end
  if not fragment or fragment:match("^%s*$") then return true, nil end
  local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
  local tmp = HOME .. "/.TermAI/.validation_tmp.lua"
  local test = "return function()\n" .. fragment .. "\nend"
  local f = io.open(tmp, "w")
  if not f then return true, nil end
  f:write(test)
  f:close()
  local h = io.popen("luac -p " .. tmp .. " 2>&1")
  if not h then os.remove(tmp); return true, nil end
  local out = h:read("*a")
  h:close()
  os.remove(tmp)
  out = out:match("^%s*(.-)%s*$")
  if out == "" then return true, nil end
  local err_line = out:match("stdin:(%d+):")
  if err_line then
    err_line = tonumber(err_line) - 1
    if err_line > 0 then
      out = out:gsub("stdin:%d+:", "trecho novo linha " .. err_line .. ":")
    end
  end
  return false, out
end

return M
