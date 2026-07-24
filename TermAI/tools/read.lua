-- tools/read.lua — Ferramenta "Read" (era ler_arquivo).
-- Melhoria: exibe header com tamanho, linhas e chars antes do conteúdo,
-- permitindo ao agente decidir usar grep ou intervalo sem chamada extra.
local init = require("tools.read.init")

local M = {}
M.register = init.register

return M
