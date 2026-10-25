-- tools/exec/security.lua — Análise de segurança para comandos bash

local M = {}

local N = require("tools.exec.security.nucleo")(M)
require("tools.exec.security.parte_1")(M, N)
require("tools.exec.security.parte_2")(M, N)

return M
