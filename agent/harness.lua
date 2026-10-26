-- agent/harness.lua — Fachada do Harness² (experimental, desligado por padrão).
-- Fase 1: só o gancho depois do turno. Com a opção desligada, não faz nada
-- e não chama nenhum modelo. O ciclo de verdade fica em agent/harness/ciclo.lua.
local M = {}

-- A opção fica em agents.defaults.harness2.enabled no config.json.
function M.ativo()
  local ok, cfg = pcall(function() return require("config").load() end)
  if not ok or type(cfg) ~= "table" then return false end
  local h = cfg.agents and cfg.agents.defaults and cfg.agents.defaults.harness2
  return type(h) == "table" and h.enabled == true
end

-- Chamado depois de cada turno normal. Retorna um estado, sem efeito colateral.
function M.depois_do_turno(turno)
  if not M.ativo() then return { status = "desativado" } end
  return { status = "pendente", turno = turno }
end

return M
