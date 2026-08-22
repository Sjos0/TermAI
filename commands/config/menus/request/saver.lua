-- commands/config/menus/request/saver.lua — Camada de persistência das configurações de request.
local config_mod = require("config")

local M = {}

-- Grava um parâmetro de requisição no config.json e sincroniza com o contexto ativo
function M.save_req(ctx, key, val)
  if not ctx.cfg.agents.defaults.request then
    ctx.cfg.agents.defaults.request = {}
  end
  ctx.cfg.agents.defaults.request[key] = val
  config_mod.set("agents.defaults.request." .. key, val)
end

-- Grava um parâmetro direto em agents.defaults (fora de request), ex: thinkingEffort
function M.save_defaults(ctx, key, val)
  if not ctx.cfg.agents.defaults then
    ctx.cfg.agents.defaults = {}
  end
  ctx.cfg.agents.defaults[key] = val
  config_mod.set("agents.defaults." .. key, val)
end

return M
