-- input.lua — Fachada + Loop principal de input raw com suporte a bracketed paste.
-- Interface pública: M.read(), M.paste_counter, M.pasted_texts
-- [WARN] stty raw/sane são operações atômicas fora do pcall — preservar ordem exata.
local M = {}

local N = require("ui.input.nucleo_1")(M)
require("ui.input.parte_1")(M, N)
require("ui.input.parte_2")(M, N)

return M
