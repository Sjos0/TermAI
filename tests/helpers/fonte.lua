-- tests/helpers/fonte.lua — Lê o código-fonte de um módulo como texto, incluindo as
-- partes geradas pela divisão (arquivos .lua da pasta de mesmo nome).
-- Specs que conferem padrões no código usam isto, para não depender de onde a
-- implementação foi parar depois de uma divisão em fachada + partes.
local M = {}

local function ler_arquivo(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local s = f:read("*a") or ""
  f:close()
  return s
end

-- caminho sem extensão, ex: "agent/compaction/init" ou "tools/exec/security".
-- Devolve o texto do arquivo principal e de todos os .lua da pasta correspondente.
function M.ler(caminho)
  local base = caminho:match("%.lua$") and caminho or (caminho .. ".lua")
  local pasta = base:match("/init%.lua$") and base:gsub("/init%.lua$", "") or base:gsub("%.lua$", "")
  local partes = { ler_arquivo(base) or "" }
  local p = io.popen("ls '" .. pasta .. "' 2>/dev/null")
  if p then
    for nome in p:lines() do
      if nome:match("%.lua$") and nome ~= "init.lua" then
        partes[#partes + 1] = ler_arquivo(pasta .. "/" .. nome) or ""
      end
    end
    p:close()
  end
  return table.concat(partes, "\n")
end

return M
