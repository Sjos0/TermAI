-- ui/tools_init/parser.lua — Analisador de comandos de ferramentas e suas métricas.
local M = {}

-- Divide uma string de comando no formato "Nome | Argumentos"
function M.parse_cmd(cmd)
  cmd = cmd:gsub("[\r\n]+", " ")
  local name, arg = cmd:match("^(.-)%s+|%s+(.-)%s*$")
  if not name or name == "" then
    return cmd, nil
  end
  return name, (arg ~= "" and arg or nil)
end

-- Determina de forma centralizada se um Edit teve alteração real de linhas (DRY)
function M.is_edit_success(out, ok)
  if not out then return ok end
  local a, r = out:match("METRICS:%s*added=(%d+),%s*removed=(%d+)")
  if a and r and tonumber(a) == 0 and tonumber(r) == 0 then
    return false
  end
  return ok
end

return M
