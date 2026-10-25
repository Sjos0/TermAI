-- commands/config/menus/request/actions.lua — Camada controladora (Controller) de ações do menu.

local M = {}

local N = require("commands.config.menus.request.actions.nucleo")(M)
require("commands.config.menus.request.actions.parte_1")(M, N)
require("commands.config.menus.request.actions.parte_2")(M, N)

return M
