-- tools/helpers.lua — Utilitários compartilhados entre módulos de ferramentas.
-- Importado por exec, read, files, workspace e qualquer módulo que precise
-- de expand_path, validação lua ou informações de arquivo.

local M = {}

local HOME         = os.getenv("HOME") or "/data/data/com.termux/files/home"
M.PROJECT_ROOT     = HOME .. "/.TermAI"

-- ── Expansão de caminhos ────────────────────────────────────────────────────
function M.expand_path(path)
  path = path:match("^%s*(.-)%s*$")
  if path:sub(1,1) == "~" then return HOME .. path:sub(2) end
  if path:sub(1,1) == "/" then return path end
  if path:match("^workspace/") or path == "workspace" then
    return M.PROJECT_ROOT .. "/" .. path
  end
  return M.PROJECT_ROOT .. "/workspace/" .. path
end

-- ── Sanitização de string para shell ────────────────────────────────────────
function M.shell_safe(str)
  return str:gsub("[^%w%.%_%-%/ ]", "")
end

-- ── Validação de sintaxe Lua ─────────────────────────────────────────────────
function M.luac_validate(path)
  if not path:match("%.lua$") then return nil end
  local wh = io.popen("which luac 2>/dev/null")
  local has_luac = wh and wh:read("*a") or ""
  if wh then wh:close() end
  if has_luac:match("%S") then
    local h = io.popen('luac -p "' .. path .. '" 2>&1')
    local out = h and h:read("*a") or ""
    if h then h:close() end
    out = out:gsub("%s+$", "")
    return out == "" and "✅ luac -p: OK" or ("⚠️ luac -p ERRO:\n" .. out)
  else
    local h = io.popen('lua -e "local f,e=loadfile([[' .. path .. ']]); if not f then io.write(e) end" 2>&1')
    local out = h and h:read("*a") or ""
    if h then h:close() end
    out = out:gsub("%s+$", "")
    return out == "" and "✅ lua loadfile: OK" or ("⚠️ lua loadfile ERRO:\n" .. out)
  end
end

-- ── Informações de arquivo (Princípio 3: output que informa decisões) ────────
-- Retorna string com tamanho, linhas e chars calculados do conteúdo em memória.
-- Evita syscall extra: reutiliza o conteúdo já lido pelo chamador.
function M.file_info(content)
  local bytes = #content
  local size_str
  if bytes >= 1024 * 1024 then
    size_str = string.format("%.1f MB", bytes / (1024 * 1024))
  elseif bytes >= 1024 then
    size_str = string.format("%.1f KB", bytes / 1024)
  else
    size_str = bytes .. " bytes"
  end
  local lines = 0
  if content ~= "" then
    for _ in content:gmatch("\n") do lines = lines + 1 end
    if content:sub(-1) ~= "\n" then
      lines = lines + 1
    end
  end
  return string.format("📊 %s | %d linhas | %d chars", size_str, lines, bytes)
end

return M
