-- providers.lua — Fachada: adicionar, remover e atualizar provedores de IA.
-- Interface pública: M.add, M.remove, M.update_key,
-- M.add_provider (alias), M.remove_provider (alias), M.update_api_key (alias)
local add_mod        = require("commands.models.providers.add")
local remove_mod     = require("commands.models.providers.remove")
local update_key_mod = require("commands.models.providers.update_key")
local M = {}

M.add        = add_mod.add
M.remove     = remove_mod.remove
M.update_key = update_key_mod.update_key

-- Aliases para menu.lua encontrar as funções corretas
M.add_provider    = M.add
M.remove_provider = M.remove
M.update_api_key  = M.update_key

return M
