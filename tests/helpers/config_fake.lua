-- tests/helpers/config_fake.lua — Config em memória para specs de permissão.
-- Issue #129: sem isso, o spec lê e grava ~/.TermAI/config.json do próprio usuário: regras
-- salvas por ele (ex: allow "sort *") mudam o resultado e o spec quebra.
local M = {}

local function copy(t)
  if type(t) ~= "table" then return t end
  local out = {}
  for k, v in pairs(t) do out[k] = copy(v) end
  return out
end

-- Instala um módulo "config" falso em package.loaded. Chamar ANTES de
-- require de qualquer módulo que dependa de config (ex: tools.exec.permissions).
function M.install()
  local store = {}
  package.loaded["config"] = {
    load = function() return copy(store) end,
    save = function(cfg) store = copy(cfg) end,
  }
  return store
end

return M
