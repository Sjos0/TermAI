-- models.lua — Fachada: listar, ativar, detalhar, adicionar e remover modelos.
-- Interface pública: M.list, M.set, M.info, M.add, M.remove
local list_mod   = require("commands.models.models.list")
local info_mod   = require("commands.models.models.info")
local add_mod    = require("commands.models.models.add")
local remove_mod = require("commands.models.models.remove")
local set_mod    = require("commands.models.models.set")
local M = {}

M.list   = list_mod.list
M.set    = set_mod.set
M.info   = info_mod.info
M.add    = add_mod.add
M.remove = remove_mod.remove

return M
