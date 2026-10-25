-- commands/config_cli/menus/request.lua
-- Menu de Requisicoes: timeout, retries, mode, reasoning effort.
local M = {}

local N = require("commands.config_cli.menus.request.nucleo")(M)
require("commands.config_cli.menus.request.parte_1")(M, N)

return M
