-- tools/subagents/control.lua — Comandos de controle: listar, detalhes com progresso, esperar, log e matar.
local M = {}

local N = require("tools.subagents.control.nucleo_1")(M)
require("tools.subagents.control.parte_1")(M, N)
require("tools.subagents.control.parte_2")(M, N)

return M
