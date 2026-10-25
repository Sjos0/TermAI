-- session_cmds.lua — Comandos de sessão (/new, /reset, /status, /session).
-- Reset de flush: /new e /reset zeram o flush_state para o ciclo recomeçar.


local M = {}

local N = require("agent.session_cmds.nucleo_1")(M)
require("agent.session_cmds.parte_1")(M, N)
require("agent.session_cmds.parte_2")(M, N)

return M
