-- tools/exec/permissions_ui.lua — Interface TUI de diálogo para permissões
-- v5: diálogo modal em alternate screen (ESC[?1049h / ESC[?1049l]).
--     Tela principal intacta; sem contagem de linhas, sem ESC[1A/2K.
--     Cleanup garantido via xpcall mesmo em erro.

local M = {}

local N = require("tools.exec.permissions_ui.nucleo_2")(M)
require("tools.exec.permissions_ui.parte_1")(M, N)

return M
