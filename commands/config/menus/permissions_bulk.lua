-- permissions_bulk.lua — Ação em lote do menu de permissões: "Sempre" para todas as ferramentas.
-- Bloqueios explícitos (blocked) são preservados. Regras de deny do bash continuam valendo.
local M = {}

-- Só "s", "S" ou "sim" confirmam. Qualquer outra resposta, inclusive vazia, cancela.
function M.is_confirmed(resposta)
  local texto = tostring(resposta or ""):match("^%s*(.-)%s*$"):lower()
  return texto == "s" or texto == "sim"
end

-- Grava "always" em cada ferramenta de nomes, exceto as bloqueadas.
-- Retorna quantas foram liberadas e a lista das preservadas.
function M.allow_all(perms_mod, nomes)
  local liberadas, preservadas = 0, {}
  for _, nome in ipairs(nomes) do
    if perms_mod.get(nome) == "blocked" then
      preservadas[#preservadas + 1] = nome
    else
      perms_mod.set(nome, "always")
      liberadas = liberadas + 1
    end
  end
  return liberadas, preservadas
end

return M
