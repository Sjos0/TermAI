-- commands/config/menus/web_tools.lua
-- Menu de Web Tools na TUI: escolher provedor principal, chaves e cadeia de fallback.
local M = {}

local N = require("commands.config.menus.web_tools.nucleo_1")(M)
require("commands.config.menus.web_tools.parte_1")(M, N)

return M
