-- tests/helpers/config_sandbox.lua — Isola o config.json usado pelos specs.
-- Redireciona config.store.PATH para um arquivo temporário. Assim nenhum spec
-- lê nem grava ~/.TermAI/config.json do usuário (regras "sempre" e modo de permissão).
-- Chamar logo no início do spec, antes de qualquer require de módulo de config.
local M = {}

local function pasta_temporaria()
  local base = os.getenv("TMPDIR")
  if not base or base == "" then base = "/tmp" end
  return base
end

-- Retorna o caminho do config temporário usado por este processo.
function M.install()
  local store = require("config.store")
  local caminho = string.format("%s/termai_test_config_%d_%d.json",
    pasta_temporaria(), os.time(), math.random(1, 1000000000))
  store.PATH = caminho
  store._data = nil
  M.caminho = caminho
  M._limpeza = setmetatable({}, { __gc = function() os.remove(caminho) end })
  return caminho
end

return M
