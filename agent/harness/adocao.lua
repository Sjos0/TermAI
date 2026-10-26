-- agent/harness/adocao.lua — Gravação atômica do harness adotado.
-- Escreve em arquivo temporário e troca com os.rename, para que uma queda no meio
-- nunca deixe o harness pela metade. Só aceita nomes simples (sem barra).
local M = {}

function M.nome_valido(nome)
  return type(nome) == "string" and nome:match("^[%w_%-]+%.md$") ~= nil
end

function M.gravar(dir, nome, conteudo)
  if not M.nome_valido(nome) then return nil, "nome_invalido" end
  if dir:find("['\"]") then return nil, "diretorio_invalido" end
  os.execute("mkdir -p '" .. dir .. "'")
  local final = dir .. "/" .. nome
  local tmp = final .. ".tmp"
  local f = io.open(tmp, "w")
  if not f then return nil, "nao_abriu" end
  f:write(conteudo or "")
  f:close()
  local ok, err = os.rename(tmp, final)
  if not ok then return nil, tostring(err) end
  return true
end

return M
